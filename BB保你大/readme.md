# BB保你大 — AI Remaster Workflow

Documented workflow used to AI-remaster the 52-episode Cantonese-dubbed series **BB保你大**.

The objective was to preserve the original audio and frame rate while improving the SD video using Real-ESRGAN and producing high-quality 1080p 4:3 HEVC masters.

---

## Final Remaster Specification

| Property | Value |
|---|---|
| Source | SD |
| Typical source resolution | 640×480 |
| Final resolution | 1440×1080 |
| Aspect ratio | 4:3 |
| Frame rate | Original frame rate preserved, typically 24 fps |
| AI model | Real-ESRGAN `realesr-animevideov3` |
| AI upscale | 4× |
| AI intermediate | Typically 2560×1920 |
| Downscale | Lanczos |
| Final codec | HEVC / H.265 |
| Encoder | x265 |
| Preset | Slow |
| CRF | 20 |
| Pixel format | yuv420p |
| Audio | Original AAC |
| Audio language | Cantonese (`yue`) |
| Audio re-encoding | None |
| Frame interpolation | None |
| Remaster year | 2026 |

The original video frames are extracted losslessly to PNG, processed through Real-ESRGAN, downscaled to 1440×1080, and encoded with x265.

The original Cantonese AAC audio is stream-copied into the remastered MKV without re-encoding.

---

# Requirements

The workflow assumes the following are installed and available:

- FFmpeg
- FFprobe
- Real-ESRGAN NCNN Vulkan
- PowerShell
- Sufficient temporary storage

Real-ESRGAN was installed at:

```text
C:\Real-ESRGAN
```

The following model was used:

```text
realesr-animevideov3
```

Available model files included:

```text
realesr-animevideov3-x2
realesr-animevideov3-x3
realesr-animevideov3-x4
realesrgan-x4plus-anime
realesrgan-x4plus
```

---

# Temporary Storage Requirements

The frame-based workflow uses a large amount of temporary storage.

For a typical ~20-minute episode:

```text
Source frames:
~29,500 PNG files
~5.9 GB

AI-upscaled frames:
~29,500 PNG files
~114 GB

Expected temporary working space:
~120–125 GB
```

A minimum free-space threshold of:

```text
160 GB
```

is therefore used before starting each episode.

Temporary frames are deleted after each episode completes successfully.

---

# Starting the AI Remaster Job

Update these paths as required:

```powershell
$SourceDir = "C:\Users\Synice\Downloads\BB保你大"
$OutputDir = "C:\Users\Synice\Downloads\BB保你大\Upscaled"
$WorkRoot = "C:\Real-ESRGAN\batch-work"
$RealESRGAN = "C:\Real-ESRGAN\realesrgan-ncnn-vulkan.exe"

$MinimumFreeGB = 160
$StartEpisode = 1

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
New-Item -ItemType Directory -Force -Path $WorkRoot | Out-Null

$Files = Get-ChildItem $SourceDir -Filter "*.mp4" |
    Where-Object {
        if ($_.BaseName -match '^(\d+)-') {
            [int]$matches[1] -ge $StartEpisode
        } else {
            $false
        }
    } |
    Sort-Object {
        if ($_.BaseName -match '^(\d+)-') {
            [int]$matches[1]
        } else {
            9999
        }
    }

foreach ($File in $Files) {

    if ($File.BaseName -match '^(\d+)-') {
        $Episode = [int]$matches[1]
    }
    else {
        continue
    }

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
    Write-Host ""

    #
    # Restart behaviour
    #
    # The selected StartEpisode is treated as a fresh restart point.
    # Any incomplete temporary files and output for that episode are removed.
    #

    if ($Episode -eq $StartEpisode) {
        Remove-Item $EpisodeWork -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $OutputFile -Force -ErrorAction SilentlyContinue
    }
    elseif (Test-Path $OutputFile) {
        Write-Host "$EpisodeTag already exists. Skipping."
        continue
    }

    #
    # Free-space check
    #

    $FreeGB = [math]::Round((Get-PSDrive C).Free / 1GB, 2)

    Write-Host "C: free space: $FreeGB GB"

    if ($FreeGB -lt $MinimumFreeGB) {
        Write-Error "$EpisodeTag NOT STARTED - only $FreeGB GB free. Minimum is $MinimumFreeGB GB."
        break
    }

    #
    # Prepare temporary directories
    #

    Remove-Item $EpisodeWork -Recurse -Force -ErrorAction SilentlyContinue

    New-Item -ItemType Directory -Force -Path $Frames | Out-Null
    New-Item -ItemType Directory -Force -Path $Upscaled | Out-Null

    #
    # Detect source frame rate
    #

    $FrameRateRaw = ffprobe `
        -v error `
        -select_streams v:0 `
        -show_entries stream=avg_frame_rate `
        -of default=noprint_wrappers=1:nokey=1 `
        "$($File.FullName)"

    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($FrameRateRaw)) {
        Write-Error "Could not detect frame rate for $EpisodeTag"
        break
    }

    Write-Host "Detected FPS: $FrameRateRaw"

    #
    # Extract source video frames losslessly
    #

    Write-Host ""
    Write-Host "Extracting frames..."

    ffmpeg `
        -hide_banner `
        -i "$($File.FullName)" `
        -map 0:v:0 `
        -fps_mode passthrough `
        "$Frames\frame_%08d.png"

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Frame extraction failed for $EpisodeTag"
        break
    }

    $FrameCount = (Get-ChildItem "$Frames\*.png").Count

    Write-Host "Extracted $FrameCount frames."

    #
    # AI upscale using Real-ESRGAN
    #

    Write-Host ""
    Write-Host "AI upscaling with realesr-animevideov3..."

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

    $UpscaledCount = (Get-ChildItem "$Upscaled\*.png").Count

    Write-Host "Upscaled $UpscaledCount frames."

    if ($UpscaledCount -ne $FrameCount) {
        Write-Error "$EpisodeTag frame-count mismatch. Source=$FrameCount Upscaled=$UpscaledCount"
        break
    }

    #
    # Encode final 1440×1080 HEVC video
    #

    Write-Host ""
    Write-Host "Encoding 1440x1080 HEVC..."

    ffmpeg `
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

    #
    # Verify output
    #

    Write-Host ""
    Write-Host "Verifying output..."

    ffprobe `
        -v error `
        -show_entries "stream=index,codec_name,codec_type,width,height,avg_frame_rate,pix_fmt:stream_tags=language,title:format=duration,size,bit_rate" `
        -of default=noprint_wrappers=1 `
        "$OutputFile"

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Output verification failed for $EpisodeTag"
        break
    }

    #
    # Cleanup temporary frames
    #

    Write-Host ""
    Write-Host "Cleaning temporary frames..."

    Remove-Item $EpisodeWork -Recurse -Force

    Write-Host ""
    Write-Host "$EpisodeTag COMPLETE"
    Write-Host "Output: $OutputFile"
}

Write-Host ""
Write-Host "============================================"
Write-Host " Batch processing finished"
Write-Host "============================================"
```

---

# Restarting After an Interrupted Job

Set:

```powershell
$StartEpisode = 42
```

for example, to restart from episode 42.

The script will delete temporary and incomplete output belonging to the selected starting episode, then continue processing episodes after it.

Completed episodes before `$StartEpisode` are not touched.

> **Important:** Do not set `$StartEpisode` to an already completed episode unless you intend to regenerate that episode.

---

# AI Remaster Metadata

After all episodes have been processed successfully, metadata is added in a separate pass.

This operation uses:

```text
-c copy
```

so the completed video and audio streams are **not re-encoded**.

```powershell
$Dir = "C:\Users\Synice\Downloads\BB保你大\Upscaled"

$Files = Get-ChildItem $Dir -Filter "EP??-1080p.mkv" |
    Sort-Object Name

foreach ($File in $Files) {

    if ($File.BaseName -match '^EP(\d+)-1080p$') {
        $Episode = [int]$matches[1]
    }
    else {
        Write-Warning "Skipping unexpected filename: $($File.Name)"
        continue
    }

    $EpisodeTag = "EP{0:D2}" -f $Episode
    $TempFile = Join-Path $Dir "$EpisodeTag-1080p.metadata-temp.mkv"

    Write-Host ""
    Write-Host "============================================"
    Write-Host " Updating metadata for $EpisodeTag"
    Write-Host "============================================"

    ffmpeg `
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
        Remove-Item $TempFile -Force -ErrorAction SilentlyContinue
        break
    }

    #
    # Verify new file
    #

    ffprobe `
        -v error `
        -show_entries "format_tags=title,edition,remaster_year,ai_model,ai_scale,output_resolution,remaster_method,video_codec,video_encode,audio_source,comment:stream=index,codec_name,codec_type,width,height:stream_tags=language,title" `
        -of default=noprint_wrappers=1 `
        "$TempFile"

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Verification failed for $EpisodeTag"
        break
    }

    #
    # Replace original only after successful remux
    #

    Remove-Item "$($File.FullName)" -Force
    Move-Item "$TempFile" "$($File.FullName)"

    Write-Host "$EpisodeTag metadata updated."
}

Write-Host ""
Write-Host "============================================"
Write-Host " Metadata pass complete"
Write-Host "============================================"
```

---

## Embedded Metadata

Each remastered MKV contains metadata similar to:

```text
Title: BB保你大 - EP01
Edition: AI Remastered
Remaster Year: 2026
AI Model: Real-ESRGAN realesr-animevideov3
AI Scale: 4x
Output Resolution: 1440x1080
Remaster Method: AI upscale 4x using realesr-animevideov3, downscaled to 1440x1080 with Lanczos
Video Codec: HEVC / H.265
Video Encode: x265 CRF 20 preset slow
Audio Source: Original Cantonese AAC
Audio Language: yue
Audio Title: Cantonese
```

---

# SHA-256 Integrity Manifest

After all metadata changes are complete, SHA-256 hashes are generated for the final files.

**Generate hashes only after the metadata pass.**

Changing MKV metadata changes the file contents and therefore changes the SHA-256 hash.

Set the final archive directory:

```powershell
$Folder = "C:\Users\Synice\OneDrive\HK-Anime\BB保你大"
$Manifest = Join-Path $Folder "SHA256SUMS.txt"

$Files = Get-ChildItem $Folder -Filter "EP*-1080p.mkv" |
    Sort-Object {
        if ($_.BaseName -match '^EP(\d+)') {
            [int]$matches[1]
        } else {
            9999
        }
    }

if ($Files.Count -ne 52) {
    Write-Warning "Expected 52 episodes but found $($Files.Count)."
}

$Lines = foreach ($File in $Files) {

    Write-Host "Hashing $($File.Name)..."

    $Hash = Get-FileHash $File.FullName -Algorithm SHA256

    "$($Hash.Hash.ToLower()) *$($File.Name)"
}

$Lines | Set-Content $Manifest -Encoding UTF8

Write-Host ""
Write-Host "Done."
Write-Host "Hashed $($Files.Count) files."
Write-Host "Manifest: $Manifest"
```

The resulting manifest has the format:

```text
<sha256> *EP01-1080p.mkv
<sha256> *EP02-1080p.mkv
<sha256> *EP03-1080p.mkv
...
<sha256> *EP52-1080p.mkv
```

The SHA-256 manifest allows archived or cloud-stored files to be checked later for byte-for-byte integrity.

---

# Archive Layout

Example final archive:

```text
BB保你大/
│
├── EP01-1080p.mkv
├── EP02-1080p.mkv
├── EP03-1080p.mkv
├── ...
├── EP52-1080p.mkv
│
├── BB保你大 - AI Remastered Edition.txt
└── SHA256SUMS.txt
```

---

# Preservation Notes

The remaster deliberately preserves:

- original frame rate
- original Cantonese audio
- original audio codec
- original temporal structure
- original 4:3 presentation

The workflow does **not** use:

- frame interpolation
- artificial 60 fps conversion
- audio enhancement/re-encoding
- 16:9 stretching
- cropping to widescreen

The resulting `1440×1080` files retain the original **4:3 aspect ratio**.

---

# Storage / Cloud Archival

The completed master files may be stored on OneDrive or other cloud storage.

SHA-256 hashes verify the actual file contents, including:

- video
- audio
- MKV structure
- embedded metadata

Cloud or filesystem attributes such as:

- Windows creation time
- local file attributes
- OneDrive online/offline state

are not used as integrity indicators.

If the SHA-256 hash matches the value in `SHA256SUMS.txt`, the file is effectively verified as byte-for-byte identical to the archived master.
