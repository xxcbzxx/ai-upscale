#requires -Version 5.1
<#
.SYNOPSIS
  Verify the GXL remastered MKVs against their original MP4 sources.
.DESCRIPTION
  Read-only metadata and full decoding checks. Writes a CSV report.
  Exit code 0: all episodes passed; 1: at least one failed.
.EXAMPLE
  .\02-Verify-Remaster.ps1
.EXAMPLE
  .\02-Verify-Remaster.ps1 -SkipDecode -ExpectedEpisodes 52
#>
[CmdletBinding()]
param(
    [string]$SourceDir = 'D:\Data\GXL',
    [string]$OutputDir = 'D:\Data\GXL\Upscaled',
    [string]$ReportPath = '',
    [int]$ExpectedEpisodes = 52,
    [double]$FPSTolerance = 0.01,
    [double]$DurationToleranceSeconds = 0.1,
    [int]$TargetWidth = 1920,
    [int]$TargetHeight = 1080,
    [switch]$SkipDecode
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Rate([string]$Rational) {
    if ($Rational -match '^(-?\d+(?:\.\d+)?)/(-?\d+(?:\.\d+)?)$') {
        $den = [double]$Matches[2]
        if ($den -eq 0) { return [double]::NaN }
        return ([double]$Matches[1] / $den)
    }
    $parsed = 0.0
    if ([double]::TryParse($Rational, [ref]$parsed)) { return $parsed }
    return [double]::NaN
}

function Get-MediaInfo([string]$Path) {
    $raw = & ffprobe -v error -count_frames -show_entries 'format=duration:stream=index,codec_type,codec_name,width,height,avg_frame_rate,nb_read_frames,sample_rate,channels' -of json -- $Path 2>&1
    if ($LASTEXITCODE -ne 0) { throw "ffprobe failed: $($raw -join ' ')" }
    $info = ($raw -join "`n") | ConvertFrom-Json
    if (-not $info.streams) { throw 'No streams found' }
    return $info
}

function Get-EpisodeMap([string]$Directory, [string]$Filter) {
    $map = @{}
    foreach ($file in @(Get-ChildItem -LiteralPath $Directory -File -Filter $Filter)) {
        if ($file.BaseName -match '^(\d+)-') {
            $number = [int]$Matches[1]
            if (-not $map.ContainsKey($number)) { $map[$number] = @() }
            $map[$number] += $file
        }
    }
    return $map
}

foreach ($tool in @('ffprobe', 'ffmpeg')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "$tool not found in PATH. Install FFmpeg and make ffmpeg.exe and ffprobe.exe accessible."
    }
}
if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) { throw "Missing source directory: $SourceDir" }
if (-not (Test-Path -LiteralPath $OutputDir -PathType Container)) { throw "Missing output directory: $OutputDir" }
if ([string]::IsNullOrWhiteSpace($ReportPath)) { $ReportPath = Join-Path $OutputDir 'GXL-Final-QA.csv' }

$sourceMap = Get-EpisodeMap $SourceDir '*.mp4'
$outputMap = Get-EpisodeMap $OutputDir '*-Remastered-1080p.mkv'
$numbers = if ($ExpectedEpisodes -gt 0) { @(1..$ExpectedEpisodes) } else { @($sourceMap.Keys + $outputMap.Keys | Sort-Object -Unique) }
$results = @()

foreach ($episode in $numbers) {
    $issues = [System.Collections.Generic.List[string]]::new()
    $src = $null; $dst = $null
    $sv = $null; $ov = $null
    $sa = @(); $oa = @()
    $srcFrames = $null; $outFrames = $null
    $srcRate = $null; $outRate = $null
    $srcDuration = $null; $outDuration = $null
    $resolution = $null; $videoCodec = $null; $audioCodec = $null
    $decodeStatus = if ($SkipDecode) { 'SKIPPED' } else { 'NOT_RUN' }

    if (-not $sourceMap.ContainsKey($episode)) { $issues.Add('Source missing') }
    elseif ($sourceMap[$episode].Count -ne 1) { $issues.Add('Duplicate source episode numbers') }
    else { $src = $sourceMap[$episode][0] }

    if (-not $outputMap.ContainsKey($episode)) { $issues.Add('Output missing') }
    elseif ($outputMap[$episode].Count -ne 1) { $issues.Add('Duplicate output episode numbers') }
    else { $dst = $outputMap[$episode][0] }

    if ($src -and $dst) {
        try {
            $sourceInfo = Get-MediaInfo $src.FullName
            $outputInfo = Get-MediaInfo $dst.FullName
            $sv = @($sourceInfo.streams | Where-Object { $_.codec_type -eq 'video' }) | Select-Object -First 1
            $ov = @($outputInfo.streams | Where-Object { $_.codec_type -eq 'video' }) | Select-Object -First 1
            $sa = @($sourceInfo.streams | Where-Object { $_.codec_type -eq 'audio' })
            $oa = @($outputInfo.streams | Where-Object { $_.codec_type -eq 'audio' })
            if (-not $sv -or -not $ov) { throw 'Missing video stream' }

            $srcFrames = [long]$sv.nb_read_frames
            $outFrames = [long]$ov.nb_read_frames
            $srcRate = Get-Rate ([string]$sv.avg_frame_rate)
            $outRate = Get-Rate ([string]$ov.avg_frame_rate)
            $srcDuration = [double]$sourceInfo.format.duration
            $outDuration = [double]$outputInfo.format.duration
            $resolution = "$($ov.width)x$($ov.height)"
            $videoCodec = [string]$ov.codec_name
            $audioCodec = (@($oa | ForEach-Object { $_.codec_name }) -join ',')

            if ($srcFrames -ne $outFrames) { $issues.Add('Frame count mismatch') }
            if ([double]::IsNaN($srcRate) -or [double]::IsNaN($outRate) -or [math]::Abs($srcRate - $outRate) -gt $FPSTolerance) { $issues.Add('FPS mismatch') }
            if ([math]::Abs($srcDuration - $outDuration) -gt $DurationToleranceSeconds) { $issues.Add('Duration mismatch') }
            if ($ov.width -ne $TargetWidth -or $ov.height -ne $TargetHeight) { $issues.Add('Resolution mismatch') }
            if ($ov.codec_name -ne 'hevc') { $issues.Add('Video is not HEVC') }
            if ($sa.Count -ne $oa.Count) { $issues.Add('Audio stream count mismatch') }
            else {
                for ($i = 0; $i -lt $sa.Count; $i++) {
                    if ($sa[$i].codec_name -ne $oa[$i].codec_name -or
                        $sa[$i].sample_rate -ne $oa[$i].sample_rate -or
                        $sa[$i].channels -ne $oa[$i].channels) {
                        $issues.Add("Audio characteristics mismatch at stream $i")
                    }
                }
            }
            if ($sa.Count -eq 0) { $issues.Add('Source contains no audio') }

            if (-not $SkipDecode) {
                # -xerror makes decoding errors fatal; null muxer writes no output file.
                $decodeOutput = & ffmpeg -hide_banner -nostdin -v error -xerror -i $dst.FullName -map '0:v:0' -f null NUL 2>&1
                if ($LASTEXITCODE -eq 0) { $decodeStatus = 'PASS' }
                else {
                    $decodeStatus = 'FAIL'
                    $issues.Add("Video decode failed: $(($decodeOutput -join ' ') -replace '[\r\n]+', ' ')")
                }
            }
        }
        catch { $issues.Add("Probe or verification failed: $($_.Exception.Message)") }
    }

    $status = if ($issues.Count -eq 0) { 'PASS' } else { 'FAIL' }
    $results += [pscustomobject]@{
        Episode = $episode
        Status = $status
        SourceFrames = $srcFrames
        OutputFrames = $outFrames
        SourceFPS = if ($null -ne $srcRate) { [math]::Round($srcRate, 6) } else { $null }
        OutputFPS = if ($null -ne $outRate) { [math]::Round($outRate, 6) } else { $null }
        SourceDuration = $srcDuration
        OutputDuration = $outDuration
        Resolution = $resolution
        VideoCodec = $videoCodec
        AudioCodec = $audioCodec
        VideoDecode = $decodeStatus
        Issues = $issues -join '; '
    }
    $colour = if ($status -eq 'PASS') { 'Green' } else { 'Red' }
    Write-Host ('EP{0:D2}: {1}  {2}' -f $episode, $status, ($issues -join '; ')) -ForegroundColor $colour
}

$results | Export-Csv -LiteralPath $ReportPath -NoTypeInformation -Encoding UTF8
$pass = @($results | Where-Object { $_.Status -eq 'PASS' }).Count
$fail = @($results | Where-Object { $_.Status -eq 'FAIL' }).Count
Write-Host "`nGXL verification: PASS=$pass FAIL=$fail TOTAL=$($results.Count)"
Write-Host "Report: $ReportPath"
if ($fail -gt 0) { exit 1 }
exit 0
