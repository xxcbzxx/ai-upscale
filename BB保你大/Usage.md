# BB保你大 AI Remaster — Usage Guide

This document describes how to use the PowerShell scripts included with the **BB保你大 AI Remaster** workflow.

The workflow consists of four stages:

```text
01-Upscale.ps1
       │
       ▼
02-Metadata.ps1
       │
       ▼
03-SHA256.ps1
       │
       ▼
04-Verify-SHA256.ps1
```

The scripts perform the following tasks:

| Script | Purpose |
|---|---|
| `01-Upscale.ps1` | Extract frames, AI upscale with Real-ESRGAN, and encode the remastered MKV |
| `02-Metadata.ps1` | Add remaster metadata and correct the Cantonese audio language tag |
| `03-SHA256.ps1` | Generate SHA-256 checksums for the completed masters |
| `04-Verify-SHA256.ps1` | Verify archived files against the SHA-256 manifest |

---

# 1. Requirements

The workflow was designed for **Windows PowerShell**.

The following software is required:

- PowerShell
- FFmpeg
- FFprobe
- Real-ESRGAN NCNN Vulkan
- Vulkan-compatible GPU
- Sufficient temporary disk space

FFmpeg and FFprobe should be available through `PATH`.

Test with:

```powershell
ffmpeg -version
ffprobe -version
```

Real-ESRGAN should contain:

```text
realesrgan-ncnn-vulkan.exe
models\
```

The model used for this project is:

```text
realesr-animevideov3
```

Real-ESRGAN is not distributed as part of this project.

Official project:

https://github.com/xinntao/Real-ESRGAN/

---

# 2. Source File Naming

`01-Upscale.ps1` determines the episode number from the beginning of each source filename.

Source files should therefore begin with:

```text
1-
2-
3-
...
52-
```

For example:

```text
1-example.mp4
2-example.mp4
3-example.mp4
...
52-example.mp4
```

The remainder of the filename can contain other information.

Only `.mp4` source files are processed by the current script.

---

# 3. Processing Specification

The BB保你大 remaster was produced using:

```text
Source:             SD
Typical source:     640x480
Aspect ratio:       4:3
Frame rate:         Original preserved (typically 24 fps)

AI model:           realesr-animevideov3
AI scale:           4x
AI intermediate:    typically 2560x1920

Final resolution:   1440x1080
Downscaling:        Lanczos

Video codec:        HEVC / H.265
Encoder:            x265
Preset:             slow
CRF:                20
Pixel format:        yuv420p

Audio:               Original AAC
Audio re-encoding:   None
Audio language:      Cantonese (yue)

Frame interpolation: None
```

The original frame rate is detected using FFprobe rather than being manually forced to 24 fps.

---

# 4. Temporary Disk Space

The upscale process creates lossless PNG frames.

For a typical approximately 20-minute episode, temporary storage can exceed:

```text
Source PNG frames:       ~6 GB
AI-upscaled PNG frames: ~114 GB
Other/output data:       additional space
```

Approximately **120–125 GB** may therefore be required during processing.

The script uses a default safety threshold of:

```text
160 GB
```

If the working drive has less free space than this, the next episode will not begin.

Temporary frames are automatically deleted after an episode completes successfully.

---

# 5. Stage 1 — AI Upscale

## Script

```text
01-Upscale.ps1
```

This is the main processing script.

It performs:

```text
Source MP4
    │
    ├── FFprobe
    │     └── Detect original frame rate
    │
    ├── FFmpeg
    │     └── Extract lossless PNG frames
    │
    ├── Real-ESRGAN
    │     └── AI upscale frames 4x
    │
    ├── Frame-count verification
    │
    ├── FFmpeg / x265
    │     ├── Lanczos resize to 1440x1080
    │     ├── HEVC CRF 20 / slow
    │     └── Copy original AAC audio
    │
    ├── FFprobe verification
    │
    └── Delete temporary frames
```

## Basic Usage

For example:

```powershell
.\01-Upscale.ps1 `
    -SourceDir "D:\Anime\BB保你大" `
    -RealESRGANDir "C:\Real-ESRGAN"
```

If `OutputDir` is not specified, output is written to:

```text
<SourceDir>\Upscaled
```

For example:

```text
D:\Anime\BB保你大\Upscaled
```

The resulting files are:

```text
EP01-1080p.mkv
EP02-1080p.mkv
...
EP52-1080p.mkv
```

---

## Specify an Output Directory

An explicit destination can be supplied:

```powershell
.\01-Upscale.ps1 `
    -SourceDir "D:\Anime\BB保你大" `
    -OutputDir "E:\Remastered\BB保你大" `
    -RealESRGANDir "C:\Real-ESRGAN"
```

---

## Change Minimum Free Space

The default is:

```text
160 GB
```

It can be changed with:

```powershell
.\01-Upscale.ps1 `
    -SourceDir "D:\Anime\BB保你大" `
    -RealESRGANDir "C:\Real-ESRGAN" `
    -MinimumFreeGB 180
```

Reducing this value significantly is not recommended when processing complete episodes using PNG frames.

---

# 6. Restarting an Interrupted Upscale

The upscale operation can take a considerable amount of time.

A reboot, power failure, disk-space problem, or other interruption may leave:

```text
batch-work\EPxx\
```

and possibly an incomplete:

```text
EPxx-1080p.mkv
```

Use `StartEpisode` to restart from that episode.

For example, if processing was interrupted during episode 42:

```powershell
.\01-Upscale.ps1 `
    -SourceDir "D:\Anime\BB保你大" `
    -RealESRGANDir "C:\Real-ESRGAN" `
    -StartEpisode 42
```

The script treats the selected starting episode as a **fresh restart point**.

For EP42 in this example it will:

```text
Delete incomplete EP42 temporary files
Delete incomplete EP42 output
Reprocess EP42 from the beginning
Continue with EP43
Continue with EP44
...
```

Episodes before EP42 are not processed.

> [!WARNING]
> The output belonging to `StartEpisode` is deliberately deleted before processing.
>
> Do not set `StartEpisode` to a completed episode unless you intend to regenerate that episode.

---

# 7. Stage 2 — Metadata

## Script

```text
02-Metadata.ps1
```

Run this **after all 52 episodes have completed successfully**.

Example:

```powershell
.\02-Metadata.ps1 `
    -Dir "D:\Anime\BB保你大\Upscaled"
```

This adds remaster information such as:

```text
Title:             BB保你大 - EP01
Edition:           AI Remastered
Remaster Year:     2026
AI Model:          Real-ESRGAN realesr-animevideov3
AI Scale:          4x
Output Resolution: 1440x1080
Video Codec:       HEVC / H.265
Video Encode:      x265 CRF 20 preset slow
Audio Source:      Original Cantonese AAC
```

It also explicitly changes the audio stream metadata to:

```text
Language: yue
Title:    Cantonese
```

This is important when the source incorrectly identifies the Cantonese audio as English.

---

## Does Metadata Processing Re-encode the Video?

No.

The metadata script uses:

```text
-c copy
```

The existing video and audio streams are copied into a new MKV container.

There is no second x265 encode and no AAC re-encode.

The process is therefore substantially faster than the AI-upscaling stage.

---

## Safe Replacement

The metadata script initially creates:

```text
EP01-1080p.metadata-temp.mkv
```

It verifies that file with FFprobe.

Only after successful creation and verification does it replace:

```text
EP01-1080p.mkv
```

This reduces the chance of replacing a completed remaster with an unsuccessful metadata operation.

---

# 8. Stage 3 — Generate SHA-256 Manifest

## Script

```text
03-SHA256.ps1
```

Run this **after the metadata stage is completely finished**.

Example:

```powershell
.\03-SHA256.ps1 `
    -Folder "D:\Anime\BB保你大\Upscaled"
```

For a OneDrive archive, for example:

```powershell
.\03-SHA256.ps1 `
    -Folder "C:\Users\YourName\OneDrive\HK-Anime\BB保你大"
```

The script generates:

```text
SHA256SUMS.txt
```

Example contents:

```text
428ec7... *EP01-1080p.mkv
9620ac... *EP02-1080p.mkv
7a7e52... *EP03-1080p.mkv
...
d1fe92... *EP52-1080p.mkv
```

Each complete entry contains a 64-character SHA-256 digest.

---

# 9. Why SHA-256 Must Be Generated Last

MKV metadata is part of the file itself.

Therefore:

```text
Original remaster
      │
      ├── SHA-256 = A
      │
      ▼
Metadata changed
      │
      └── SHA-256 = B
```

Even though the encoded video and audio streams were not re-encoded, changing the MKV structure or metadata changes the file's bytes.

Therefore the correct order is:

```text
Upscale
   ↓
Metadata
   ↓
SHA-256
```

Do **not** generate the final integrity manifest before completing the metadata pass.

---

# 10. OneDrive and Cloud Storage

The completed files can be stored in OneDrive.

For example:

```text
OneDrive\
└── HK-Anime\
    └── BB保你大\
        ├── EP01-1080p.mkv
        ├── EP02-1080p.mkv
        ├── ...
        ├── EP52-1080p.mkv
        ├── BB保你大 - AI Remastered Edition.txt
        └── SHA256SUMS.txt
```

When generating or verifying checksums, OneDrive online-only files must be downloaded so PowerShell can read their complete contents.

For a large collection it may be easier to select the folder in Windows Explorer and use:

```text
Always keep on this device
```

before starting the checksum operation.

---

# 11. Stage 4 — Verify SHA-256

## Script

```text
04-Verify-SHA256.ps1
```

This script checks the current files against:

```text
SHA256SUMS.txt
```

Example:

```powershell
.\04-Verify-SHA256.ps1 `
    -Folder "D:\Recovered\BB保你大"
```

It calculates a fresh SHA-256 hash for each episode and compares it with the archived value.

A successful result should resemble:

```text
[CHECK]   EP01-1080p.mkv ... OK
[CHECK]   EP02-1080p.mkv ... OK
[CHECK]   EP03-1080p.mkv ... OK

...

============================================
 Verification complete
============================================

PASSED:  52
FAILED:  0
MISSING: 0

All files passed SHA-256 verification.
```

---

# 12. Failed Verification

If a file has changed, the script reports:

```text
[CHECK]   EP17-1080p.mkv ... FAILED

Expected: <original SHA-256>
Actual:   <current SHA-256>
```

This means the current file is **not byte-for-byte identical** to the file used when `SHA256SUMS.txt` was generated.

Possible reasons include:

- file corruption
- accidental modification
- metadata modification
- remuxing
- re-encoding
- replacing the episode with another copy
- an incomplete transfer/download

A hash mismatch does not by itself identify which part of the MKV changed.

---

# 13. Missing Files

If an episode listed in the manifest cannot be found:

```text
[MISSING] EP27-1080p.mkv
```

the verification summary will report it:

```text
PASSED:  51
FAILED:  0
MISSING: 1
```

---

# 14. What SHA-256 Verifies

SHA-256 operates on the complete file.

A successful match therefore verifies the bytes representing the:

- HEVC video
- AAC audio
- MKV container
- embedded metadata
- stream metadata
- other data contained in the MKV

It does **not** depend upon filesystem attributes such as:

- Windows creation date
- Windows file attributes
- NTFS permissions
- OneDrive sync state
- online-only/local availability status

For example, a file could be downloaded from OneDrive years later with a different Windows `Created` timestamp while still producing exactly the same SHA-256 digest.

---

# 15. Recommended Complete Workflow

For a new remaster:

### Step 1 — Process the source episodes

```powershell
.\01-Upscale.ps1 `
    -SourceDir "D:\Anime\BB保你大" `
    -RealESRGANDir "C:\Real-ESRGAN"
```

### Step 2 — Apply final metadata

```powershell
.\02-Metadata.ps1 `
    -Dir "D:\Anime\BB保你大\Upscaled"
```

### Step 3 — Move/copy final masters to archive storage

For example:

```text
OneDrive\HK-Anime\BB保你大
```

### Step 4 — Generate the final integrity manifest

```powershell
.\03-SHA256.ps1 `
    -Folder "C:\Users\YourName\OneDrive\HK-Anime\BB保你大"
```

### Step 5 — Allow the manifest to sync

The archive should now contain:

```text
BB保你大\
│
├── EP01-1080p.mkv
├── EP02-1080p.mkv
├── ...
├── EP52-1080p.mkv
│
├── BB保你大 - AI Remastered Edition.txt
└── SHA256SUMS.txt
```

### Step 6 — Verify whenever required

```powershell
.\04-Verify-SHA256.ps1 `
    -Folder "C:\Users\YourName\OneDrive\HK-Anime\BB保你大"
```

---

# 16. Processing Order

The four scripts should normally be run in this order:

```text
┌───────────────────────────────┐
│ Source MP4 episodes           │
└───────────────┬───────────────┘
                │
                ▼
       01-Upscale.ps1
                │
                ▼
┌───────────────────────────────┐
│ 1440x1080 HEVC remasters      │
│ Original Cantonese AAC        │
└───────────────┬───────────────┘
                │
                ▼
       02-Metadata.ps1
                │
                ▼
┌───────────────────────────────┐
│ Final remastered masters      │
│ Cantonese tagged as yue       │
└───────────────┬───────────────┘
                │
                ▼
        03-SHA256.ps1
                │
                ▼
┌───────────────────────────────┐
│ SHA256SUMS.txt                │
└───────────────┬───────────────┘
                │
                ▼
       Archive / OneDrive
                │
                ▼
     04-Verify-SHA256.ps1
                │
                ▼
┌───────────────────────────────┐
│ 52 PASSED / 0 FAILED          │
│ Archive integrity confirmed   │
└───────────────────────────────┘
```

---

# 17. Important Notes

> [!IMPORTANT]
> `01-Upscale.ps1` can consume more than 120 GB of temporary storage for a single episode. Ensure sufficient free space before processing.

> [!IMPORTANT]
> Run `03-SHA256.ps1` only after all intended changes to the MKV files have been completed.

> [!WARNING]
> `StartEpisode` in `01-Upscale.ps1` is a destructive restart point for that episode. The selected episode's existing output is removed before regeneration.

> [!NOTE]
> The original Cantonese AAC audio is copied rather than re-encoded.

> [!NOTE]
> No frame interpolation is performed. The source frame rate is preserved.

> [!NOTE]
> The 4:3 material is output as 1440×1080 rather than stretched to 1920×1080.

---

# 18. Script Summary

```text
01-Upscale.ps1
    Input:  Original numbered MP4 episodes
    Output: EPxx-1080p.mkv
    Heavy processing: YES
    Re-encodes video: YES
    Re-encodes audio: NO

02-Metadata.ps1
    Input:  EPxx-1080p.mkv
    Output: Updated EPxx-1080p.mkv
    Heavy processing: NO
    Re-encodes video: NO
    Re-encodes audio: NO

03-SHA256.ps1
    Input:  Final EPxx-1080p.mkv files
    Output: SHA256SUMS.txt
    Modifies MKV files: NO

04-Verify-SHA256.ps1
    Input:  EPxx-1080p.mkv + SHA256SUMS.txt
    Output: Integrity verification report
    Modifies MKV files: NO
```

---

## Real-ESRGAN

This workflow uses **Real-ESRGAN**.

- **Official repository:** [xinntao/Real-ESRGAN](https://github.com/xinntao/Real-ESRGAN/)
- **Research paper:** [Real-ESRGAN: Training Real-World Blind Super-Resolution with Pure Synthetic Data](https://arxiv.org/abs/2107.10833)

Real-ESRGAN binaries and pretrained models are not included with this workflow. Refer to the official upstream project for downloads, licensing, installation instructions, and current documentation.
