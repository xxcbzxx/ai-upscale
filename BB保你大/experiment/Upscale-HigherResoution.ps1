param(
    [Parameter(Mandatory = $true)]
    [string]$SourceDir,

    [string]$OutputDir,

    [string]$RealESRGANDir = "C:\Real-ESRGAN",

    [Parameter(Mandatory = $true)]
    [ValidateSet("2K", "4K", "8K")]
    [string]$Target,

    [int]$StartEpisode = 1,

    [int]$MinimumFreeGB = 160,

    [int]$CRF = -1
)

$ErrorActionPreference = "Stop"

# ============================================================
# Target resolution configuration
#
# All targets retain the original 4:3 presentation.
#
# 2K -> 2048x1536
# 4K -> 2880x2160
# 8K -> 5760x4320
# ============================================================

switch ($Target) {

    "2K" {
        $TargetWidth = 2048
        $TargetHeight = 1536

        if ($CRF -lt 0) {
            $CRF = 20
        }
    }

    "4K" {
        $TargetWidth = 2880
        $TargetHeight = 2160

        if ($CRF -lt 0) {
            $CRF = 19
        }
    }

    "8K" {
        $TargetWidth = 5760
        $TargetHeight = 4320

        if ($CRF -lt 0) {
            $CRF = 18
        }
    }
}

# ============================================================
# Paths
# ============================================================

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $SourceDir "Upscaled-$Target"
}

$WorkRoot = Join-Path $RealESRGANDir "batch-work-$Target"

$RealESRGAN = Join-Path `
    $RealESRGANDir `
    "realesrgan-ncnn-vulkan.exe"

# ============================================================
# Requirements
# ============================================================

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

New-Item `
    -ItemType Directory `
    -Force `
    -Path $OutputDir |
    Out-Null

New-Item `
    -ItemType Directory `
    -Force `
    -Path $WorkRoot |
    Out-Null

# ============================================================
# Locate source episodes
#
# Expected naming:
#
# 1-example.mp4
# 2-example.mp4
# ...
# 52-example.mp4
# ============================================================

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

# ============================================================
# Job summary
# ============================================================

Write-Host ""
Write-Host "================================================"
Write-Host " BB保你大 Higher Resolution AI Remaster"
Write-Host "================================================"
Write-Host ""
Write-Host "Source directory : $SourceDir"
Write-Host "Output directory : $OutputDir"
Write-Host "Work directory   : $WorkRoot"
Write-Host ""
Write-Host "Target           : $Target"
Write-Host "Resolution       : ${TargetWidth}x${TargetHeight}"
Write-Host "Aspect ratio     : 4:3"
Write-Host ""
Write-Host "AI model         : realesr-animevideov3"
Write-Host "AI scale         : 4x"
Write-Host "Encoder          : x265"
Write-Host "CRF              : $CRF"
Write-Host "Preset           : slow"
Write-Host ""
Write-Host "Starting episode : EP$('{0:D2}' -f $StartEpisode)"
Write-Host "Episodes queued  : $($Files.Count)"
Write-Host ""

# ============================================================
# Episode loop
# ============================================================

foreach ($File in $Files) {

    if ($File.BaseName -notmatch '^(\d+)-') {
        continue
    }

    $Episode = [int]$matches[1]
    $EpisodeTag = "EP{0:D2}" -f $Episode

    $EpisodeWork = Join-Path `
        $WorkRoot `
        $EpisodeTag

    $Frames = Join-Path `
        $EpisodeWork `
        "frames"

    $Upscaled = Join-Path `
        $EpisodeWork `
        "upscaled"

    $OutputFile = Join-Path `
        $OutputDir `
        "$EpisodeTag-$Target.mkv"

    Write-Host ""
    Write-Host "================================================"
    Write-Host " Processing $EpisodeTag - $Target"
    Write-Host " $($File.Name)"
    Write-Host "================================================"
    Write-Host ""

    # ========================================================
    # Restart behaviour
    #
    # StartEpisode is considered a fresh restart point.
    # ========================================================

    if ($Episode -eq $StartEpisode) {

        Remove-Item `
            $EpisodeWork `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue

        Remove-Item `
            $OutputFile `
            -Force `
            -ErrorAction SilentlyContinue
    }
    elseif (Test-Path $OutputFile) {

        Write-Host "$EpisodeTag $Target already exists - skipping."
        continue
    }

    # ========================================================
    # Free-space check
    # ========================================================

    $WorkDrive = (Get-Item $RealESRGANDir).PSDrive

    $FreeGB = [math]::Round(
        $WorkDrive.Free / 1GB,
        2
    )

    Write-Host "Working-drive free space: $FreeGB GB"

    if ($FreeGB -lt $MinimumFreeGB) {

        Write-Error `
            "$EpisodeTag NOT STARTED - $FreeGB GB free; minimum is $MinimumFreeGB GB."

        break
    }

    # ========================================================
    # Prepare temporary directories
    # ========================================================

    Remove-Item `
        $EpisodeWork `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue

    New-Item `
        -ItemType Directory `
        -Force `
        -Path $Frames |
        Out-Null

    New-Item `
        -ItemType Directory `
        -Force `
        -Path $Upscaled |
        Out-Null

    # ========================================================
    # Detect source properties
    # ========================================================

    Write-Host ""
    Write-Host "Detecting source properties..."

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

    $SourceResolution = & ffprobe `
        -v error `
        -select_streams v:0 `
        -show_entries stream=width,height `
        -of csv=s=x:p=0 `
        "$($File.FullName)"

    $SourceResolution = $SourceResolution.Trim()

    Write-Host "Source resolution : $SourceResolution"
    Write-Host "Source frame rate : $FrameRateRaw"

    # ========================================================
    # Extract source frames
    # ========================================================

    Write-Host ""
    Write-Host "Extracting lossless source frames..."

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

        Write-Error "No frames extracted for $EpisodeTag"
        break
    }

    # ========================================================
    # AI upscale
    #
    # Always perform ONE AI generation from the original
    # source frames.
    #
    # Typical source:
    #
    # 640x480
    #     |
    #     v
    # Real-ESRGAN x4
    #     |
    #     v
    # 2560x1920
    #
    # The AI output is then resized to the selected target.
    # ========================================================

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

    # ========================================================
    # Final encode
    # ========================================================

    Write-Host ""
    Write-Host "Encoding $Target (${TargetWidth}x${TargetHeight})..."
    Write-Host ""

    & ffmpeg `
        -hide_banner `
        -framerate "$FrameRateRaw" `
        -i "$Upscaled\frame_%08d.png" `
        -i "$($File.FullName)" `
        -map 0:v:0 `
        -map 1:a? `
        -map_metadata 1 `
        -vf "scale=${TargetWidth}:${TargetHeight}:flags=lanczos,setsar=1" `
        -c:v libx265 `
        -preset slow `
        -crf $CRF `
        -pix_fmt yuv420p `
        -c:a copy `
        -metadata "title=BB保你大 - $EpisodeTag - $Target AI Remaster" `
        -metadata "edition=$Target AI Remastered" `
        -metadata "remaster_year=2026" `
        -metadata "source_resolution=$SourceResolution" `
        -metadata "ai_model=Real-ESRGAN realesr-animevideov3" `
        -metadata "ai_scale=4x" `
        -metadata "output_resolution=${TargetWidth}x${TargetHeight}" `
        -metadata "remaster_method=Original SD source -> Real-ESRGAN x4 -> Lanczos resize to ${TargetWidth}x${TargetHeight}" `
        -metadata "video_codec=HEVC / H.265" `
        -metadata "video_encode=x265 CRF $CRF preset slow" `
        -metadata "audio_source=Original Cantonese AAC" `
        -metadata "comment=Higher-resolution AI remaster generated directly from the original SD source. Original frame rate and Cantonese audio preserved. No frame interpolation performed." `
        -metadata:s:a:0 language=yue `
        -metadata:s:a:0 title="Cantonese" `
        -shortest `
        "$OutputFile"

    if ($LASTEXITCODE -ne 0) {

        Write-Error "Encoding failed for $EpisodeTag"
        break
    }

    # ========================================================
    # Verify output
    # ========================================================

    Write-Host ""
    Write-Host "Verifying $OutputFile..."
    Write-Host ""

    & ffprobe `
        -v error `
        -show_entries `
        "stream=index,codec_name,codec_type,width,height,avg_frame_rate,pix_fmt:stream_tags=language,title:format=duration,size,bit_rate:format_tags=title,edition,source_resolution,ai_model,ai_scale,output_resolution" `
        -of default=noprint_wrappers=1 `
        "$OutputFile"

    if ($LASTEXITCODE -ne 0) {

        Write-Error "Output verification failed for $EpisodeTag"
        break
    }

    # ========================================================
    # Cleanup
    # ========================================================

    Write-Host ""
    Write-Host "Cleaning temporary frames..."

    Remove-Item `
        $EpisodeWork `
        -Recurse `
        -Force

    Write-Host ""
    Write-Host "$EpisodeTag $Target COMPLETE"
    Write-Host "Output: $OutputFile"
}

Write-Host ""
Write-Host "================================================"
Write-Host " Higher-resolution batch processing finished"
Write-Host "================================================"
