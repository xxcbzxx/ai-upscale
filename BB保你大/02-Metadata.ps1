param(
    [Parameter(Mandatory = $true)]
    [string]$Dir
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $Dir)) {
    throw "Directory not found: $Dir"
}

if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    throw "ffmpeg was not found in PATH."
}

if (-not (Get-Command ffprobe -ErrorAction SilentlyContinue)) {
    throw "ffprobe was not found in PATH."
}

$Files = Get-ChildItem $Dir -Filter "EP??-1080p.mkv" |
    Sort-Object {
        if ($_.BaseName -match '^EP(\d+)') {
            [int]$matches[1]
        }
        else {
            9999
        }
    }

Write-Host "Found $($Files.Count) remastered episodes."

if ($Files.Count -ne 52) {
    Write-Warning "Expected 52 episodes."
}

foreach ($File in $Files) {

    if ($File.BaseName -notmatch '^EP(\d+)-1080p$') {
        Write-Warning "Skipping: $($File.Name)"
        continue
    }

    $Episode = [int]$matches[1]
    $EpisodeTag = "EP{0:D2}" -f $Episode

    $TempFile = Join-Path `
        $Dir `
        "$EpisodeTag-1080p.metadata-temp.mkv"

    Write-Host ""
    Write-Host "============================================"
    Write-Host " Updating metadata for $EpisodeTag"
    Write-Host "============================================"

    & ffmpeg `
        -hide_banner `
        -y `
        -i "$($File.FullName)" `
        -map 0 `
        -c copy `
        -metadata "title=BB保你大 - $EpisodeTag" `
        -metadata "edition=AI Remastered" `
        -metadata "remaster_year=2026" `
        -metadata "ai_model=Real-ESRGAN realesr-animevideov3" `
        -metadata "ai_scale=4x" `
        -metadata "output_resolution=1440x1080" `
        -metadata "remaster_method=AI upscale 4x using realesr-animevideov3, downscaled to 1440x1080 with Lanczos" `
        -metadata "video_codec=HEVC / H.265" `
        -metadata "video_encode=x265 CRF 20 preset slow" `
        -metadata "audio_source=Original Cantonese AAC" `
        -metadata "comment=AI remastered from the original SD source. Original frame rate and Cantonese audio preserved. No frame interpolation performed." `
        -metadata:s:a:0 language=yue `
        -metadata:s:a:0 title="Cantonese" `
        "$TempFile"

    if ($LASTEXITCODE -ne 0) {

        Write-Error "Metadata remux failed for $EpisodeTag"

        Remove-Item $TempFile `
            -Force `
            -ErrorAction SilentlyContinue

        break
    }

    # --------------------------------------------------------
    # Verify temporary file before replacing master
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "Verifying metadata..."

    & ffprobe `
        -v error `
        -show_entries `
        "format_tags=title,edition,remaster_year,ai_model,ai_scale,output_resolution,remaster_method,video_codec,video_encode,audio_source,comment:stream=index,codec_name,codec_type,width,height:stream_tags=language,title" `
        -of default=noprint_wrappers=1 `
        "$TempFile"

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Verification failed for $EpisodeTag"
        break
    }

    # --------------------------------------------------------
    # Replace original only after successful verification
    # --------------------------------------------------------

    Remove-Item "$($File.FullName)" -Force
    Move-Item "$TempFile" "$($File.FullName)"

    Write-Host ""
    Write-Host "$EpisodeTag metadata updated."
}

Write-Host ""
Write-Host "============================================"
Write-Host " Metadata pass complete"
Write-Host "============================================"
