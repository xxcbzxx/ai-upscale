param(
    [Parameter(Mandatory=$false)]
    [string]$Path = ".",

    [Parameter(Mandatory=$false)]
    [string]$OutputCsv = ".\video-scan-results.csv"
)

$ErrorActionPreference = "Stop"

function Convert-RationalToDouble {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    if ($Value -match "^(\d+)\/(\d+)$") {
        $num = [double]$Matches[1]
        $den = [double]$Matches[2]

        if ($den -eq 0) {
            return $null
        }

        return $num / $den
    }

    try {
        return [double]$Value
    }
    catch {
        return $null
    }
}

function Get-Recommendation {
    param(
        [int]$Width,
        [int]$Height,
        [double]$FPS,
        [string]$FieldOrder,
        [string]$DAR,
        [long]$VideoBitrate,
        [string]$Codec
    )

    $reasons = @()

    if ($FieldOrder -and $FieldOrder -ne "progressive" -and $FieldOrder -ne "unknown") {
        return [PSCustomObject]@{
            Candidate = $false
            Decision  = "REVIEW_INTERLACED"
            Reason    = "Source appears interlaced. Deinterlace analysis required before any AI upscale."
        }
    }

    if ($Height -ge 1080) {
        return [PSCustomObject]@{
            Candidate = $false
            Decision  = "ALREADY_1080_HEIGHT"
            Reason    = "Already 1080 pixels high; do not upscale automatically."
        }
    }

    if ($Width -le 0 -or $Height -le 0) {
        return [PSCustomObject]@{
            Candidate = $false
            Decision  = "UNKNOWN"
            Reason    = "Resolution could not be determined."
        }
    }

    if ($Height -le 576) {
        $reasons += "SD source ($Width x $Height)"
    }

    if ($VideoBitrate -gt 0 -and $VideoBitrate -lt 350000) {
        $reasons += "very low video bitrate"
    }
    elseif ($VideoBitrate -gt 0 -and $VideoBitrate -lt 800000) {
        $reasons += "low video bitrate"
    }

    if ($FPS -gt 0 -and $FPS -notin @(23.976, 24, 25, 29.97, 30, 50, 59.94, 60)) {
        $reasons += "unusual frame rate"
    }

    if ($Height -le 576 -and $FieldOrder -eq "progressive") {
        return [PSCustomObject]@{
            Candidate = $true
            Decision  = "GOOD_AI_CANDIDATE"
            Reason    = ($reasons -join "; ")
        }
    }

    if ($Height -lt 1080) {
        return [PSCustomObject]@{
            Candidate = $true
            Decision  = "REVIEW_FOR_UPSCALE"
            Reason    = if ($reasons.Count -gt 0) {
                $reasons -join "; "
            } else {
                "Below 1080p; manual quality review recommended."
            }
        }
    }

    return [PSCustomObject]@{
        Candidate = $false
        Decision  = "NO_UPSCALE_NEEDED"
        Reason    = "No automatic upscale recommendation."
    }
}

$extensions = @(
    "*.mp4",
    "*.mkv",
    "*.avi",
    "*.mov",
    "*.m4v",
    "*.ts",
    "*.m2ts",
    "*.webm"
)

$files = foreach ($ext in $extensions) {
    Get-ChildItem -Path $Path -File -Recurse -Filter $ext -ErrorAction SilentlyContinue
}

$files = $files | Sort-Object FullName -Unique

if (-not $files) {
    Write-Host "No video files found." -ForegroundColor Yellow
    exit 0
}

$results = foreach ($file in $files) {

    Write-Host "Scanning: $($file.Name)"

    try {
        $jsonText = ffprobe `
            -v quiet `
            -show_format `
            -show_streams `
            -of json `
            $file.FullName

        $probe = $jsonText | ConvertFrom-Json

        $video = $probe.streams |
            Where-Object { $_.codec_type -eq "video" } |
            Select-Object -First 1

        $audio = $probe.streams |
            Where-Object { $_.codec_type -eq "audio" } |
            Select-Object -First 1

        if (-not $video) {
            throw "No video stream found"
        }

        $fps = Convert-RationalToDouble $video.avg_frame_rate

        if (-not $fps -or $fps -eq 0) {
            $fps = Convert-RationalToDouble $video.r_frame_rate
        }

        $videoBitrate = 0

        if ($video.bit_rate) {
            $videoBitrate = [long]$video.bit_rate
        }

        $totalBitrate = 0

        if ($probe.format.bit_rate) {
            $totalBitrate = [long]$probe.format.bit_rate
        }

        $recommendation = Get-Recommendation `
            -Width ([int]$video.width) `
            -Height ([int]$video.height) `
            -FPS $fps `
            -FieldOrder ([string]$video.field_order) `
            -DAR ([string]$video.display_aspect_ratio) `
            -VideoBitrate $videoBitrate `
            -Codec ([string]$video.codec_name)

        [PSCustomObject]@{
            FileName        = $file.Name
            FullPath        = $file.FullName

            Width           = $video.width
            Height          = $video.height

            SAR             = $video.sample_aspect_ratio
            DAR             = $video.display_aspect_ratio

            FPS             = if ($fps) {
                                  [math]::Round($fps, 3)
                              } else {
                                  $null
                              }

            FrameRateRaw    = $video.avg_frame_rate
            FieldOrder      = $video.field_order

            VideoCodec      = $video.codec_name
            PixelFormat     = $video.pix_fmt
            ColorSpace      = $video.color_space
            ColorPrimaries  = $video.color_primaries
            ColorTransfer   = $video.color_transfer

            VideoKbps       = if ($videoBitrate -gt 0) {
                                  [math]::Round($videoBitrate / 1000)
                              } else {
                                  $null
                              }

            TotalKbps       = if ($totalBitrate -gt 0) {
                                  [math]::Round($totalBitrate / 1000)
                              } else {
                                  $null
                              }

            AudioCodec      = if ($audio) {
                                  $audio.codec_name
                              } else {
                                  $null
                              }

            AudioChannels   = if ($audio) {
                                  $audio.channels
                              } else {
                                  $null
                              }

            AudioSampleRate = if ($audio) {
                                  $audio.sample_rate
                              } else {
                                  $null
                              }

            DurationSeconds = if ($probe.format.duration) {
                                  [math]::Round(
                                      [double]$probe.format.duration,
                                      2
                                  )
                              } else {
                                  $null
                              }

            SizeMB          = [math]::Round(
                                  $file.Length / 1MB,
                                  2
                              )

            Candidate       = $recommendation.Candidate
            Decision        = $recommendation.Decision
            Reason          = $recommendation.Reason
        }
    }
    catch {
        [PSCustomObject]@{
            FileName        = $file.Name
            FullPath        = $file.FullName
            Width           = $null
            Height          = $null
            SAR             = $null
            DAR             = $null
            FPS             = $null
            FrameRateRaw    = $null
            FieldOrder      = $null
            VideoCodec      = $null
            PixelFormat     = $null
            ColorSpace      = $null
            ColorPrimaries  = $null
            ColorTransfer   = $null
            VideoKbps       = $null
            TotalKbps       = $null
            AudioCodec      = $null
            AudioChannels   = $null
            AudioSampleRate = $null
            DurationSeconds = $null
            SizeMB          = [math]::Round(
                                  $file.Length / 1MB,
                                  2
                              )
            Candidate       = $false
            Decision        = "ERROR"
            Reason          = $_.Exception.Message
        }
    }
}

$results |
    Export-Csv `
        -Path $OutputCsv `
        -NoTypeInformation `
        -Encoding UTF8

Write-Host ""
Write-Host "=== Scan Summary ===" -ForegroundColor Cyan

$results |
    Group-Object Decision |
    Sort-Object Count -Descending |
    Select-Object Count, Name |
    Format-Table -AutoSize

Write-Host ""
Write-Host "=== Resolution Groups ===" -ForegroundColor Cyan

$results |
    Group-Object Width, Height, FPS, FieldOrder |
    Sort-Object Count -Descending |
    Select-Object Count, Name |
    Format-Table -AutoSize

Write-Host ""
Write-Host "=== Recommended Candidates ===" -ForegroundColor Cyan

$results |
    Where-Object Candidate -eq $true |
    Select-Object `
        FileName,
        Width,
        Height,
        FPS,
        FieldOrder,
        VideoKbps,
        Decision,
        Reason |
    Format-Table -AutoSize

Write-Host ""
Write-Host "CSV written to:"
Write-Host (Resolve-Path $OutputCsv)