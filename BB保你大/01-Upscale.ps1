param(
    [Parameter(Mandatory = $true)]
    [string]$SourceDir,

    [string]$OutputDir,

    [string]$RealESRGANDir = "C:\Real-ESRGAN",

    [int]$StartEpisode = 1,

    [int]$MinimumFreeGB = 160
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $SourceDir "Upscaled"
}

$WorkRoot = Join-Path $RealESRGANDir "batch-work"
$RealESRGAN = Join-Path $RealESRGANDir "realesrgan-ncnn-vulkan.exe"

# ------------------------------------------------------------
# Requirements
# ------------------------------------------------------------

if (-not (Test-Path $SourceDir)) {
    throw "Source directory not found: $SourceDir"
}

if (-not (Test-Path $RealESRGAN)) {
    throw "Real-ESRGAN executable not found: $RealESRGAN"
}

if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    throw "ffmpeg was not found in PATH."
}

if (-not (Get-Command ffprobe -ErrorAction SilentlyContinue)) {
    throw "ffprobe was not found in PATH."
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
New-Item -ItemType Directory -Force -Path $WorkRoot | Out-Null

# ------------------------------------------------------------
# Find episodes
#
# Expected source filenames begin with the episode number:
#
# 1-example.mp4
# 2-example.mp4
# ...
# 52-example.mp4
# ------------------------------------------------------------

$Files = Get-ChildItem $SourceDir -Filter "*.mp4" |
    Where-Object {
        if ($_.BaseName -match '^(\d+)-') {
            [int]$matches[1] -ge $StartEpisode
        }
        else {
            $false
        }
    } |
    Sort-Object {
        if ($_.BaseName -match '^(\d+)-') {
            [int]$matches[1]
        }
        else {
            9999
        }
    }

if ($Files.Count -eq 0) {
    throw "No source episodes found from episode $StartEpisode."
}

Write-Host ""
Write-Host "BB保你大 AI Remaster"
Write-Host "Source:       $SourceDir"
Write-Host "Output:       $OutputDir"
Write-Host "Work:         $WorkRoot"
Write-Host "Start:        EP$('{0:D2}' -f $StartEpisode)"
Write-Host "Episodes:     $($Files.Count)"
Write-Host ""

foreach ($File in $Files) {

    if ($File.BaseName -notmatch '^(\d+)-') {
        continue
    }

    $Episode = [int]$matches[1]
    $EpisodeTag = "EP{0:D2}" -f $Episode

    $EpisodeWork = Join-Path $WorkRoot $EpisodeTag
    $Frames = Join-Path $EpisodeWork "frames"
    $Upscaled = Join-Path $EpisodeWork "upscaled"
    $OutputFile = Join-Path $OutputDir "$EpisodeTag-1080p.mkv"

    Write-Host ""
    Write-Host "============================================"
    Write-Host " Processing $EpisodeTag"
    Write-Host " $($File.Name)"
    Write-Host "============================================"

    # --------------------------------------------------------
    # Restart behaviour
    #
    # StartEpisode is treated as a fresh restart point.
    # --------------------------------------------------------

    if ($Episode -eq $StartEpisode) {

        Remove-Item $EpisodeWork `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue

        Remove-Item $OutputFile `
            -Force `
            -ErrorAction SilentlyContinue
    }
    elseif (Test-Path $OutputFile) {

        Write-Host "$EpisodeTag already exists - skipping."
        continue
    }

    # --------------------------------------------------------
    # Free-space check
    # --------------------------------------------------------

    $WorkDrive = (Get-Item $RealESRGANDir).PSDrive

    $FreeGB = [math]::Round(
        $WorkDrive.Free / 1GB,
        2
    )

    Write-Host "Working-drive free space: $FreeGB GB"

    if ($FreeGB -lt $MinimumFreeGB) {
        Write-Error `
            "$EpisodeTag NOT STARTED - $FreeGB GB free; $MinimumFreeGB GB required."
        break
    }

    # --------------------------------------------------------
    # Prepare work directories
    # --------------------------------------------------------

    Remove-Item $EpisodeWork `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue

    New-Item -ItemType Directory -Force -Path $Frames |
        Out-Null

    New-Item -ItemType Directory -Force -Path $Upscaled |
        Out-Null

    # --------------------------------------------------------
    # Detect original frame rate
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "Detecting source frame rate..."

    $FrameRateRaw = & ffprobe `
        -v error `
        -select_streams v:0 `
        -show_entries stream=avg_frame_rate `
        -of default=noprint_wrappers=1:nokey=1 `
        "$($File.FullName)"

    if (
        $LASTEXITCODE -ne 0 -or
        [string]::IsNullOrWhiteSpace($FrameRateRaw)
    ) {
        Write-Error "Could not detect frame rate for $EpisodeTag"
        break
    }

    $FrameRateRaw = $FrameRateRaw.Trim()

    Write-Host "Detected FPS: $FrameRateRaw"

    # --------------------------------------------------------
    # Extract lossless PNG frames
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "Extracting lossless PNG frames..."

    & ffmpeg `
        -hide_banner `
        -i "$($File.FullName)" `
        -map 0:v:0 `
        -fps_mode passthrough `
        "$Frames\frame_%08d.png"

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Frame extraction failed for $EpisodeTag"
        break
    }

    $FrameCount = (
        Get-ChildItem "$Frames\*.png"
    ).Count

    Write-Host "Extracted frames: $FrameCount"

    if ($FrameCount -eq 0) {
        Write-Error "No frames were extracted for $EpisodeTag"
        break
    }

    # --------------------------------------------------------
    # Real-ESRGAN
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "AI upscaling with realesr-animevideov3 x4..."

    & $RealESRGAN `
        -i "$Frames" `
        -o "$Upscaled" `
        -n realesr-animevideov3 `
        -s 4 `
        -f png

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Real-ESRGAN failed for $EpisodeTag"
        break
    }

    $UpscaledCount = (
        Get-ChildItem "$Upscaled\*.png"
    ).Count

    Write-Host "Upscaled frames: $UpscaledCount"

    if ($UpscaledCount -ne $FrameCount) {

        Write-Error `
            "$EpisodeTag frame-count mismatch. Source=$FrameCount Upscaled=$UpscaledCount"

        break
    }

    # --------------------------------------------------------
    # Final encode
    #
    # Real-ESRGAN:
    #     typically 640x480 -> 2560x1920
    #
    # FFmpeg:
    #     2560x1920 -> 1440x1080
    #
    # Audio is copied directly from the source.
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "Encoding 1440x1080 HEVC..."

    & ffmpeg `
        -hide_banner `
        -framerate "$FrameRateRaw" `
        -i "$Upscaled\frame_%08d.png" `
        -i "$($File.FullName)" `
        -map 0:v:0 `
        -map 1:a? `
        -map_metadata 1 `
        -vf "scale=1440:1080:flags=lanczos,setsar=1" `
        -c:v libx265 `
        -preset slow `
        -crf 20 `
        -pix_fmt yuv420p `
        -c:a copy `
        -metadata:s:a:0 language=yue `
        -metadata:s:a:0 title="Cantonese" `
        -shortest `
        "$OutputFile"

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Encoding failed for $EpisodeTag"
        break
    }

    # --------------------------------------------------------
    # Verify
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "Verifying output..."

    & ffprobe `
        -v error `
        -show_entries `
        "stream=index,codec_name,codec_type,width,height,avg_frame_rate,pix_fmt:stream_tags=language,title:format=duration,size,bit_rate" `
        -of default=noprint_wrappers=1 `
        "$OutputFile"

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Output verification failed for $EpisodeTag"
        break
    }

    # --------------------------------------------------------
    # Cleanup
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "Cleaning temporary frames..."

    Remove-Item $EpisodeWork -Recurse -Force

    Write-Host ""
    Write-Host "$EpisodeTag COMPLETE"
    Write-Host "$OutputFile"
}

Write-Host ""
Write-Host "============================================"
Write-Host " Batch processing finished"
Write-Host "============================================"
