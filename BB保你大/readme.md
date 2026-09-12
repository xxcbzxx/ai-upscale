# BB保你大 — AI Remaster

AI restoration and preservation workflow for the 52-episode Cantonese-dubbed animation series **BB保你大**.

The project uses **Real-ESRGAN** and **FFmpeg** to restore the original SD material while preserving the original 4:3 presentation, frame rate, and Cantonese audio.

The completed primary remaster is stored as **1440×1080 HEVC/H.265**.

> [!IMPORTANT]
> This repository contains **scripts, technical documentation, and restoration methodology only**.
>
> It does **not** contain or redistribute the original episodes, remastered episodes, copyrighted video, or copyrighted audio.
>
> Users must provide their own source media and are responsible for ensuring that their use of the material complies with applicable copyright law and any relevant licences or permissions.

---

## Source Material

The SD source files used for this project were obtained from:

### HKAnime — BB保你大 (粵語版) | 全集完 共52集

[View the source page on HKAnime](https://www.hkanime.com/play/BB%E4%BF%9D%E4%BD%A0%E5%A4%A7/582)

The source collection contains **52 Cantonese-dubbed episodes**.

Observed technical characteristics of the source material:

| Property | Source |
|---|---|
| Episodes | 52 |
| Resolution | Typically `640×480` |
| Aspect Ratio | 4:3 |
| Frame Rate | Typically 24 fps |
| Video | H.264 |
| Pixel Format | yuv420p |
| Audio | AAC Stereo |
| Audio Sample Rate | 48 kHz |
| Language | Cantonese |

Some individual source files differ slightly from the typical specification.

The processing scripts therefore use **FFprobe** to inspect source properties rather than assuming that every episode is identical.

> [!NOTE]
> The original SD files are considered the preservation source for this project.
>
> Future 2K, 4K, or 8K versions should be regenerated from the original SD material rather than from an already-remastered version.

---

# Primary AI Remaster

The primary completed edition of **BB保你大** uses the following specification:

| Property | Remaster |
|---|---|
| Source | Original SD |
| Typical Source Resolution | `640×480` |
| AI Model | `realesr-animevideov3` |
| AI Scale | 4× |
| Typical AI Intermediate | `2560×1920` |
| Final Resolution | `1440×1080` |
| Aspect Ratio | 4:3 |
| Frame Rate | Original preserved |
| Frame Interpolation | None |
| Final Video Codec | HEVC / H.265 |
| Encoder | x265 |
| CRF | 20 |
| Preset | slow |
| Pixel Format | yuv420p |
| Downscaling | Lanczos |
| Audio | Original Cantonese AAC |
| Audio Re-encoding | None |
| Audio Language Tag | `yue` |
| Remaster Year | 2026 |

The typical processing chain is:

```text
Original SD
640×480
    │
    ▼
Lossless PNG extraction
    │
    ▼
Real-ESRGAN
realesr-animevideov3 ×4
    │
    ▼
2560×1920
AI intermediate
    │
    ▼
Lanczos downscale
    │
    ▼
1440×1080
4:3
    │
    ▼
HEVC / x265
CRF 20 / preset slow
    │
    ├── Original frame rate preserved
    └── Original Cantonese AAC preserved
```

No frame interpolation is performed.

The source is **not stretched to 16:9**.

---

# Why 1440×1080?

The original material is 4:3.

A 4:3 image with a height of 1080 pixels has a width of:

```text
1440×1080
```

Using `1920×1080` as the active image would require stretching or otherwise altering the original presentation.

Instead, the remaster remains:

```text
1440×1080
```

Players such as Plex and Jellyfin can pillarbox the image appropriately when displayed on a 16:9 screen.

---

# Restoration Philosophy

The purpose of this workflow is to improve the presentation of the available SD material without unnecessarily altering its original characteristics.

The primary remaster therefore preserves:

- original 4:3 framing
- original frame rate
- original Cantonese audio
- original episode timing

The workflow does **not** intentionally perform:

- 16:9 stretching
- cropping to widescreen
- 60 fps conversion
- motion interpolation
- audio replacement
- audio re-encoding

AI processing is applied to the image frames only.

---

# Scripts

The project contains four scripts for the completed 1080p workflow.

```text
01-Upscale.ps1
02-Metadata.ps1
03-SHA256.ps1
04-Verify-SHA256.ps1
```

## `01-Upscale.ps1`

Main restoration pipeline.

It performs:

```text
FFprobe source inspection
        ↓
Lossless PNG extraction
        ↓
Real-ESRGAN ×4
        ↓
Frame-count verification
        ↓
Lanczos resize to 1440×1080
        ↓
HEVC / x265 CRF 20
        ↓
Original Cantonese AAC stream copy
        ↓
FFprobe verification
        ↓
Temporary frame cleanup
```

Example:

```powershell
.\01-Upscale.ps1 `
    -SourceDir "D:\Anime\BB保你大" `
    -RealESRGANDir "C:\Real-ESRGAN"
```

The output files are:

```text
EP01-1080p.mkv
EP02-1080p.mkv
...
EP52-1080p.mkv
```

### Restarting

If processing is interrupted, use:

```powershell
-StartEpisode
```

For example:

```powershell
.\01-Upscale.ps1 `
    -SourceDir "D:\Anime\BB保你大" `
    -RealESRGANDir "C:\Real-ESRGAN" `
    -StartEpisode 42
```

> [!WARNING]
> `StartEpisode` is treated as a fresh restart point.
>
> Existing temporary data and output for the selected episode are removed before that episode is regenerated.

---

## `02-Metadata.ps1`

Adds the final remaster metadata after processing is complete.

Example:

```powershell
.\02-Metadata.ps1 `
    -Dir "D:\Anime\BB保你大\Upscaled"
```

Metadata includes:

```text
Series:             BB保你大
Edition:            AI Remastered
Remaster Year:      2026
AI Model:           Real-ESRGAN realesr-animevideov3
AI Scale:           4x
Output Resolution:  1440x1080
Video:              HEVC / H.265
Encoding:           x265 CRF 20 preset slow
Audio:              Original Cantonese AAC
Language:           yue
```

The script uses:

```text
-c copy
```

so the existing video and audio streams are **not re-encoded** during the metadata pass.

---

## `03-SHA256.ps1`

Creates an integrity manifest for the completed masters.

Example:

```powershell
.\03-SHA256.ps1 `
    -Folder "D:\Anime\BB保你大\Upscaled"
```

The script creates:

```text
SHA256SUMS.txt
```

containing a SHA-256 digest for every episode.

> [!IMPORTANT]
> Generate the SHA-256 manifest **after all metadata modifications are complete**.
>
> Changing MKV metadata changes the file itself and therefore changes its SHA-256 digest.

---

## `04-Verify-SHA256.ps1`

Checks archived files against `SHA256SUMS.txt`.

Example:

```powershell
.\04-Verify-SHA256.ps1 `
    -Folder "D:\Archive\BB保你大"
```

A successful archive should report:

```text
PASSED:  52
FAILED:  0
MISSING: 0

All files passed SHA-256 verification.
```

A matching SHA-256 confirms that the current MKV is byte-for-byte identical to the file originally hashed.

---

# Complete Workflow

The intended order is:

```text
Original SD episodes
        │
        ▼
01-Upscale.ps1
        │
        ▼
1440×1080 AI remasters
        │
        ▼
02-Metadata.ps1
        │
        ▼
Final masters
        │
        ▼
03-SHA256.ps1
        │
        ▼
SHA256SUMS.txt
        │
        ▼
Archive / Backup
        │
        ▼
04-Verify-SHA256.ps1
        │
        ▼
Integrity confirmed
```

For detailed operating instructions see:

**[USAGE.md](./USAGE.md)**

---

# Temporary Storage Requirements

The workflow extracts every video frame to lossless PNG before processing.

During testing, a typical approximately 20-minute episode produced roughly:

```text
Source PNG frames:       ~6 GB
AI-upscaled PNG frames: ~114 GB
```

Peak temporary storage can therefore exceed:

```text
120 GB per episode
```

The default workflow requires at least:

```text
160 GB free
```

before beginning another episode.

Temporary data is reused and removed after each successful episode, so this requirement is **per episode**, not 120 GB × 52.

---

# Real-ESRGAN

This workflow uses **Real-ESRGAN**, specifically:

```text
realesr-animevideov3
```

at:

```text
4× AI scale
```

Real-ESRGAN is developed separately from this repository.

### Official Resources

- **GitHub:** [xinntao/Real-ESRGAN](https://github.com/xinntao/Real-ESRGAN/)
- **Research Paper:** [Real-ESRGAN: Training Real-World Blind Super-Resolution with Pure Synthetic Data](https://arxiv.org/abs/2107.10833)

Real-ESRGAN binaries and pretrained model files are **not distributed by this repository**.

Refer to the official upstream project for:

- downloads
- pretrained models
- licensing
- installation
- current documentation

A local reference to the Real-ESRGAN NCNN Vulkan workflow is also available in this repository:

**[Real-ESRGAN Documentation](../Real-ESRGAN/)**

---

# Future Higher-Resolution Remasters

The current recommended archival master is:

```text
1440×1080
```

Possible future experimental editions include:

| Edition | Resolution | Aspect Ratio |
|---|---:|---:|
| Current 1080p | `1440×1080` | 4:3 |
| 2K | `2048×1536` | 4:3 |
| 4K | `2880×2160` | 4:3 |
| 8K | `5760×4320` | 4:3 |

These resolutions deliberately preserve the original 4:3 presentation.

> [!IMPORTANT]
> Higher-resolution editions should be generated directly from the **original SD source**, not from the existing 1080p remaster.

The preferred relationship is:

```text
                     ┌──> 1440×1080
                     │
                     ├──> 2048×1536
Original SD ─────────┼──> 2880×2160
                     │
                     └──> 5760×4320
```

Not:

```text
Original SD
    ↓
1080p
    ↓
2K
    ↓
4K
    ↓
8K
```

This avoids repeatedly processing AI-generated detail and previously encoded video.

---

# Experimental Higher-Resolution Script

Future higher-resolution testing uses:

```text
experimental/Upscale-HigherResolution.ps1
```

The script accepts:

```powershell
-Target 2K
```

```powershell
-Target 4K
```

or:

```powershell
-Target 8K
```

For example:

### 2K

```powershell
.\Upscale-HigherResolution.ps1 `
    -SourceDir "D:\Anime\BB保你大" `
    -RealESRGANDir "C:\Real-ESRGAN" `
    -Target 2K
```

Output:

```text
2048×1536
```

### 4K

```powershell
.\Upscale-HigherResolution.ps1 `
    -SourceDir "D:\Anime\BB保你大" `
    -RealESRGANDir "C:\Real-ESRGAN" `
    -Target 4K
```

Output:

```text
2880×2160
```

### 8K

```powershell
.\Upscale-HigherResolution.ps1 `
    -SourceDir "D:\Anime\BB保你大" `
    -RealESRGANDir "C:\Real-ESRGAN" `
    -Target 8K
```

Output:

```text
5760×4320
```

> [!WARNING]
> The 2K, 4K, and particularly 8K workflows are experimental.
>
> Increasing output resolution does not recover genuine native detail that was absent from the original SD source.
>
> 4K and 8K should therefore be evaluated visually before processing the complete 52-episode collection.

See:

**[FUTURE-UPSCALING.md](./FUTURE-UPSCALING.md)**

for the full higher-resolution strategy and usage instructions.

---

# Source Policy

The original SD files should be retained wherever possible.

They are the closest available source material for future restoration work.

The conceptual archive structure is:

```text
BB保你大
│
├── Original SD
│
├── 1080p AI Remaster
│
├── Future 2K Remaster
│
├── Future 4K Remaster
│
└── Future 8K Remaster
```

Every remaster should independently originate from:

```text
Original SD
```

rather than another remaster.

This also means that future improvements to AI restoration technology can be tested without inheriting artifacts from the current Real-ESRGAN generation.

---

# Why Keep the Original SD Source?

The 1080p remaster contains pixels generated or reconstructed by the AI model.

Although the remaster may look substantially better, it is not a replacement for the original source from a preservation perspective.

Keeping the SD material allows a future workflow to use:

```text
Original SD
    ↓
New / improved restoration model
    ↓
New master
```

instead of:

```text
Old AI remaster
    ↓
New AI model
    ↓
Second-generation AI remaster
```

The original should therefore be retained alongside the remastered masters whenever possible.

---

# Archive Integrity

The recommended preservation set consists of:

```text
BB保你大/
│
├── EP01-1080p.mkv
├── EP02-1080p.mkv
├── ...
├── EP52-1080p.mkv
│
├── BB保你大 - AI Remastered Edition.txt
└── SHA256SUMS.txt
```

The SHA-256 manifest allows the masters to be verified after:

- cloud storage
- copying between disks
- backup restoration
- long-term archival
- downloading from OneDrive
- migration to new storage

Filesystem timestamps should not be used as an integrity mechanism.

---

# Plex / Jellyfin

The remastered files are suitable for use with media servers such as Plex or Jellyfin.

The active video remains:

```text
1440×1080
4:3
```

A 16:9 display should pillarbox the image during playback rather than stretching it.

The high-quality master also provides a better source if Plex or Jellyfin needs to transcode the video for a particular client or network connection.

---

# Repository Layout

Recommended project structure:

```text
ai-upscale/
│
├── README.md
├── Scan-Videos.ps1
│
├── Real-ESRGAN/
│   └── README.md
│
└── BB保你大/
    │
    ├── README.md
    ├── USAGE.md
    ├── FUTURE-UPSCALING.md
    │
    ├── 01-Upscale.ps1
    ├── 02-Metadata.ps1
    ├── 03-SHA256.ps1
    ├── 04-Verify-SHA256.ps1
    │
    └── experimental/
        └── Upscale-HigherResolution.ps1
```

The completed 1080p scripts are kept separate from experimental future-resolution workflows.

---

# Project Scope

This repository is intended to document:

- source analysis
- AI restoration methodology
- FFmpeg processing
- Real-ESRGAN processing
- frame-rate preservation
- aspect-ratio preservation
- audio preservation
- remaster metadata
- archive integrity verification
- future restoration experiments

It is **not a distribution repository for the programme itself**.

---

# Disclaimer & Attribution

This project is an independent technical restoration, preservation, and documentation project.

**BB保你大**, its animation, characters, video, Cantonese audio, programme artwork, trademarks, and other underlying copyrighted material remain the property of their respective rights holders.

No ownership of the underlying programme content is claimed by this repository or its maintainer.

The presence of a source URL in this documentation is provided for **source provenance and reproducibility of the technical workflow**. It does not represent a claim regarding ownership, licensing status, or redistribution rights of material hosted by a third party.

This repository does not include the source episodes or completed remastered episodes.

The scripts and documentation are provided for lawful personal preservation, research, technical experimentation, and other uses permitted by applicable law.

Users of these scripts are responsible for ensuring that they have the appropriate rights or permissions for the media they process.

---

## Credits

### Real-ESRGAN

Real-ESRGAN is developed by the upstream Real-ESRGAN project.

**GitHub:**  
[xinntao/Real-ESRGAN](https://github.com/xinntao/Real-ESRGAN/)

**Paper:**  
[Real-ESRGAN: Training Real-World Blind Super-Resolution with Pure Synthetic Data](https://arxiv.org/abs/2107.10833)

### FFmpeg

Video extraction, encoding, stream copying, metadata handling, and media inspection in this workflow use **FFmpeg** and **FFprobe**.

---

## Documentation

- **[Usage Guide](./USAGE.md)** — complete instructions for the four primary PowerShell scripts
- **[Future Upscaling](./FUTURE-UPSCALING.md)** — experimental 2K, 4K, and 8K strategy
- **[Real-ESRGAN Reference](../Real-ESRGAN/)** — local Real-ESRGAN reference documentation

---

**Primary Remaster:** `1440×1080` · 4:3 · HEVC/H.265 · 24 fps source timing preserved · Original Cantonese AAC · Real-ESRGAN AnimeVideoV3 ×4 · 2026
