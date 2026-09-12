# BB保你大 — AI Remaster

AI restoration and preservation workflow for the 52-episode Cantonese-dubbed animation series **BB保你大**.

This project uses **Real-ESRGAN** and **FFmpeg** to restore the available SD material while preserving the original 4:3 presentation, frame rate, episode timing, and Cantonese audio.

The completed primary remaster is stored as **1440×1080 HEVC/H.265**.

> [!IMPORTANT]
> This repository contains **scripts, technical documentation, configuration examples, and restoration methodology only**.
>
> It does **not** contain or redistribute the original episodes, remastered episodes, extracted programme frames, copyrighted video, or copyrighted audio.
>
> Users must provide their own source media and are responsible for determining whether their acquisition and use of that material complies with applicable copyright law and any relevant licences or permissions.

---

## Source Material

The SD source files used during development and testing of this project were obtained from publicly accessible online material:

### HKAnime — BB保你大 (粵語版) | 全集完 共52集

[View the source page on HKAnime](https://www.hkanime.com/play/BB%E4%BF%9D%E4%BD%A0%E5%A4%A7/582)

This source URL is recorded for **source provenance and technical documentation purposes**.

Observed technical characteristics of the source collection:

| Property | Source |
|---|---|
| Episodes | 52 |
| Resolution | Typically `640×480` |
| Aspect Ratio | 4:3 |
| Frame Rate | Typically 24 fps |
| Video Codec | H.264 |
| Pixel Format | yuv420p |
| Audio Codec | AAC |
| Audio Channels | Stereo |
| Audio Sample Rate | 48 kHz |
| Audio Language | Cantonese |

Some individual source files differ slightly from the typical specification.

The processing scripts therefore use **FFprobe** to inspect source properties rather than assuming that every episode is identical.

> [!NOTE]
> The provenance of the original broadcast/master material is unknown.
>
> The approximately 480p SD files documented above are the **best available
> source used by this project** and are retained as the preservation source
> for future restoration work.
>
> These files should not be interpreted as original masters, lossless sources,
> or first-generation copies.
---

# Primary AI Remaster

The completed primary edition of **BB保你大** uses the following specification:

| Property | Remaster |
|---|---|
| Source | Best Available SD Source |
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
| Final Resize | Lanczos |
| Audio | Original Cantonese AAC |
| Audio Re-encoding | None |
| Audio Language Tag | `yue` |
| Remaster Year | 2026 |

The typical processing chain is:

```text
Original SD
Typically 640×480
        │
        ▼
Lossless PNG extraction
        │
        ▼
Real-ESRGAN
realesr-animevideov3 ×4
        │
        ▼
Typical AI intermediate
2560×1920
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

The original programme is presented in a 4:3 aspect ratio.

A 4:3 image with a height of 1080 pixels has an active width of:

```text
1440×1080
```

Using `1920×1080` as the active image would require stretching, cropping, or otherwise altering the original presentation.

The primary remaster therefore remains:

```text
1440×1080
4:3
```

Players such as Plex and Jellyfin can pillarbox the image appropriately when it is displayed on a 16:9 screen.

---

# Restoration Philosophy

The purpose of this workflow is to improve the presentation of the available SD material without unnecessarily altering its original characteristics.

The primary remaster preserves:

- original 4:3 framing
- original frame rate
- original episode timing
- original Cantonese audio

The workflow does **not** intentionally perform:

- 16:9 stretching
- cropping to widescreen
- 60 fps conversion
- motion interpolation
- audio replacement
- audio re-encoding

AI processing is applied to the extracted video frames only.

The original audio stream is copied into the final MKV without re-encoding.

---

# Requirements

The primary workflow requires:

- Windows
- PowerShell
- FFmpeg
- FFprobe
- Real-ESRGAN NCNN Vulkan
- a Vulkan-capable GPU
- sufficient temporary disk space

The Real-ESRGAN executable is expected to be available as:

```text
realesrgan-ncnn-vulkan.exe
```

The primary AI model is:

```text
realesr-animevideov3
```

---

# Source Filename Convention

The primary batch script expects source episode filenames to begin with their episode number.

For example:

```text
1-example.mp4
2-example.mp4
3-example.mp4
...
52-example.mp4
```

The text following the episode number does not need to follow a specific naming convention.

The current production workflow searches for:

```text
*.mp4
```

and derives the episode number from the numeric prefix.

---

# Scripts

The completed 1080p workflow consists of four primary PowerShell scripts:

```text
01-Upscale.ps1
02-Metadata.ps1
03-SHA256.ps1
04-Verify-SHA256.ps1
```

They are intended to be run in that order.

---

## `01-Upscale.ps1`

This is the main restoration pipeline.

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

### Example

```powershell
.\01-Upscale.ps1 `
    -SourceDir "D:\Anime\BB保你大" `
    -RealESRGANDir "C:\Real-ESRGAN"
```

Unless another output directory is specified, output is stored beneath the source directory.

The resulting files follow the format:

```text
EP01-1080p.mkv
EP02-1080p.mkv
EP03-1080p.mkv
...
EP52-1080p.mkv
```

---

## Restarting an Interrupted Upscale

If processing is interrupted, use:

```powershell
-StartEpisode
```

For example, to restart from episode 42:

```powershell
.\01-Upscale.ps1 `
    -SourceDir "D:\Anime\BB保你大" `
    -RealESRGANDir "C:\Real-ESRGAN" `
    -StartEpisode 42
```

> [!WARNING]
> `StartEpisode` is treated as a **fresh restart point**.
>
> Existing temporary data and output for the selected episode are removed before that episode is regenerated.
>
> Do not select an already completed episode unless you intend to regenerate it.

Completed episodes after the selected restart point can be skipped when their final output already exists.

---

## `02-Metadata.ps1`

After all episodes have been successfully processed, the metadata script adds information describing the remaster.

### Example

```powershell
.\02-Metadata.ps1 `
    -Dir "D:\Anime\BB保你大\Upscaled"
```

Embedded metadata includes information such as:

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

The metadata operation uses stream copying:

```text
-c copy
```

so the existing video and audio streams are **not re-encoded** during the metadata pass.

---

## `03-SHA256.ps1`

Once the remasters and their metadata are final, this script generates a SHA-256 integrity manifest.

### Example

```powershell
.\03-SHA256.ps1 `
    -Folder "D:\Anime\BB保你大\Upscaled"
```

The script creates:

```text
SHA256SUMS.txt
```

containing a SHA-256 digest for every completed episode.

Example format:

```text
<sha256> *EP01-1080p.mkv
<sha256> *EP02-1080p.mkv
...
<sha256> *EP52-1080p.mkv
```

> [!IMPORTANT]
> Generate `SHA256SUMS.txt` **after all metadata modifications are complete**.
>
> Changing MKV metadata changes the bytes of the file and therefore changes its SHA-256 digest.

---

## `04-Verify-SHA256.ps1`

This script checks archived files against the previously generated `SHA256SUMS.txt`.

### Example

```powershell
.\04-Verify-SHA256.ps1 `
    -Folder "D:\Archive\BB保你大"
```

A successful verification should report:

```text
PASSED:  52
FAILED:  0
MISSING: 0

All files passed SHA-256 verification.
```

A matching SHA-256 confirms that the current MKV is byte-for-byte identical to the file that was originally hashed.

---

# Complete Workflow

The intended processing order is:

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

For detailed operating instructions, see:

**[USAGE.md](./USAGE.md)**

---

# Temporary Storage Requirements

The workflow extracts every source frame to lossless PNG before AI processing.

During testing, a typical approximately 20-minute episode produced roughly:

```text
Source PNG frames:       ~6 GB
AI-upscaled PNG frames: ~114 GB
```

Peak temporary storage can therefore exceed:

```text
120 GB per episode
```

The production script uses a default safety threshold of:

```text
160 GB free
```

before beginning another episode.

Temporary data is reused and removed after each successfully completed episode.

Therefore, the temporary storage requirement is approximately **120+ GB at a time**, rather than 120 GB multiplied by all 52 episodes.

---

# Real-ESRGAN

This workflow uses **Real-ESRGAN**, specifically:

```text
realesr-animevideov3
```

with:

```text
4× AI scale
```

The typical 640×480 source therefore becomes approximately:

```text
640×480
    ↓
Real-ESRGAN ×4
    ↓
2560×1920
```

The AI intermediate is then resized with Lanczos to the final archival resolution:

```text
2560×1920
    ↓
Lanczos
    ↓
1440×1080
```

Real-ESRGAN is an independent upstream project and is not part of this repository.

### Official Resources

- **GitHub:** [xinntao/Real-ESRGAN](https://github.com/xinntao/Real-ESRGAN/)
- **Research Paper:** [Real-ESRGAN: Training Real-World Blind Super-Resolution with Pure Synthetic Data](https://arxiv.org/abs/2107.10833)

Real-ESRGAN binaries and pretrained model files are **not distributed by this repository**.

Refer to the official upstream project for:

- downloads
- pretrained models
- installation
- licensing
- current documentation

A local reference for the Real-ESRGAN workflow used by this repository is available here:

**[Real-ESRGAN Documentation](../Real-ESRGAN/)**

---

# Future Higher-Resolution Remasters

The current recommended archival master remains:

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

These are project-specific 4:3 target resolutions.

In particular, the project's `4K` and `8K` labels refer to 4:3 outputs using 2160- and 4320-pixel heights respectively; they are not standard `3840×2160` or `7680×4320` 16:9 UHD rasters.

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

Avoid:

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

Repeatedly feeding an existing AI remaster through another AI restoration stage can compound:

- generated detail
- sharpening
- ringing
- line distortion
- compression artifacts
- temporal inconsistencies

Each future remaster should therefore begin again from the original SD source.

---

# Experimental Higher-Resolution Script

Experimental higher-resolution processing is kept separate from the completed production workflow:

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

---

## 2K Example

```powershell
.\Upscale-HigherResolution.ps1 `
    -SourceDir "D:\Anime\BB保你大" `
    -RealESRGANDir "C:\Real-ESRGAN" `
    -Target 2K
```

Target:

```text
2048×1536
```

---

## 4K Example

```powershell
.\Upscale-HigherResolution.ps1 `
    -SourceDir "D:\Anime\BB保你大" `
    -RealESRGANDir "C:\Real-ESRGAN" `
    -Target 4K
```

Target:

```text
2880×2160
```

---

## 8K Example

```powershell
.\Upscale-HigherResolution.ps1 `
    -SourceDir "D:\Anime\BB保你大" `
    -RealESRGANDir "C:\Real-ESRGAN" `
    -Target 8K
```

Target:

```text
5760×4320
```

---

## Higher-Resolution Processing Strategy

The experimental workflow still performs only **one AI super-resolution generation**.

For a typical 640×480 source:

```text
Original SD
640×480
    │
    ▼
Real-ESRGAN ×4
    │
    ▼
2560×1920 AI intermediate
    │
    ├── Lanczos → 2048×1536
    │
    ├── Lanczos → 2880×2160
    │
    └── Lanczos → 5760×4320
```

This is intentional.

The workflow does **not** perform something such as:

```text
640×480
    ↓
AI ×4
    ↓
2560×1920
    ↓
AI ×4 again
    ↓
10240×7680
```

A second AI generation would process detail that was already generated by the first AI pass.

> [!WARNING]
> The 2K, 4K, and particularly 8K workflows are experimental.
>
> The 4K and 8K outputs do not contain genuine native 4K or 8K source detail. They use the single Real-ESRGAN ×4 intermediate followed by conventional Lanczos resizing.
>
> Increasing the output raster does not recreate information that was never present in the original SD source.

Before processing all 52 episodes at a higher resolution, a representative episode or selection of clips should be evaluated for:

- character outlines
- faces
- Japanese title cards
- text rendering
- flat colour regions
- motion stability
- dark scenes
- compression behaviour
- temporal consistency
- Plex/Jellyfin playback compatibility

See:

**[FUTURE-UPSCALING.md](./FUTURE-UPSCALING.md)**

for the detailed experimental strategy.

---

# Source Preservation Policy

The approximately 480p SD files used for this project should be retained
wherever possible.

The provenance and generation of the original programme master are currently
unknown. Therefore, these files are described as the **Best Available SD
Source**, rather than the "Original SD Source."

Whenever the Best Available SD Source remains available, new remasters should
preferably be generated directly from it:

```text
Best Available SD Source
        │
        ├──> 1440×1080 AI Remaster
        │
        ├──> 2048×1536 Experimental Remaster
        │
        ├──> 2880×2160 Experimental Remaster
        │
        └──> 5760×4320 Experimental Remaster
---

# Why Keep the Original SD Source?

The 1080p remaster contains pixels reconstructed or generated by the AI model.

Although the remaster may look substantially better than the available SD material, it is not a replacement for that source from a preservation perspective.

Keeping the SD material allows a future workflow to use:

```text
Original SD
    ↓
Future restoration model
    ↓
New master
```

instead of:

```text
Existing AI remaster
    ↓
Future restoration model
    ↓
Second-generation AI remaster
```

This becomes particularly important as restoration models improve.

The original SD material should therefore be retained alongside the completed masters wherever possible.

---

# Archive Integrity

The completed primary remaster archive consists of:

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

- copying between disks
- cloud storage
- downloading from cloud storage
- backup restoration
- long-term archival
- migration to new storage

A matching SHA-256 digest verifies the contents of the entire MKV file, including its encoded video, audio streams, container data, and embedded metadata.

Filesystem metadata such as created/modified timestamps should **not** be used as an integrity mechanism because those values may legitimately change when files are copied, downloaded, restored, or moved between storage systems.

---

# Cloud Storage

The completed masters may be stored in private cloud storage as part of a personal archive.

When verifying files stored using services that support online-only placeholders, ensure the complete files are locally available before calculating SHA-256 hashes.

For example, with OneDrive an online-only file may need to be downloaded or marked:

```text
Always keep on this device
```

before verification.

SHA-256 should be used to determine whether the actual file content remains unchanged.

---

# Plex / Jellyfin

The remastered files are suitable for use with media servers such as Plex or Jellyfin.

The active image remains:

```text
1440×1080
4:3
```

A 16:9 client should pillarbox the image during playback rather than stretching it.

The relatively high-quality archival master also provides a better source if Plex or Jellyfin needs to transcode the video for a particular client, connection, or playback capability.

For media-library naming, the collection can optionally be arranged as a single 52-episode season:

```text
BB保你大 (1995)/
└── Season 01/
    ├── BB保你大 (1995) - S01E01.mkv
    ├── BB保你大 (1995) - S01E02.mkv
    ├── ...
    └── BB保你大 (1995) - S01E52.mkv
```

The archival filenames do not need to be changed if the archive and media-server libraries are maintained separately.

---

# Repository Layout

The project is organised as:

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

The completed and tested 1080p workflow is kept separate from experimental future-resolution workflows.

---

# Project Scope

This repository documents:

- source video analysis
- source-quality assessment
- AI restoration methodology
- lossless frame extraction
- Real-ESRGAN processing
- FFmpeg processing
- AI model selection
- resolution conversion
- aspect-ratio preservation
- frame-rate preservation
- original audio preservation
- HEVC/H.265 encoding
- remaster metadata
- SHA-256 integrity verification
- repeatable PowerShell automation
- experimental higher-resolution workflows

It is **not a distribution repository for the programme itself**.

---

# Disclaimer & Attribution

This repository documents an independent technical video restoration, AI upscaling, and preservation workflow.

**BB保你大**, including its animation, characters, video, Cantonese audio, programme artwork, trademarks, and other underlying copyrighted material, remains the property of its respective rights holders.

No ownership of the underlying programme or its copyrighted content is claimed by this repository or its maintainer.

The source material used during development of this workflow was obtained from publicly accessible online material.

The availability of material on a publicly accessible website does not necessarily grant permission to reproduce, modify, distribute, or otherwise use copyrighted material.

The source URL documented in this README is included for **source provenance and technical documentation purposes only**. Its inclusion does not represent a claim regarding the ownership, copyright status, licensing status, authorization, legality, or redistribution rights of material hosted by that third party.

This repository contains **scripts, configuration examples, technical documentation, and restoration methodology only**.

It does not contain or distribute:

- original episodes of **BB保你大**
- completed remastered episodes
- extracted programme frames
- original programme audio
- remastered programme audio
- downloadable copies of the source media

No original or remastered episodes are made publicly available through this repository.

The purpose of publishing this repository is to document the **technical processing methodology**, not to distribute the media that was processed.

The scripts contained in this repository are general-purpose media-processing and restoration tools.

Users are responsible for determining whether their acquisition, copying, processing, modification, storage, publication, or distribution of any media complies with applicable law and any relevant licences or permissions.

AI restoration, super-resolution, re-encoding, or other processing does not by itself change the ownership or copyright status of the underlying source material.

Nothing in this repository should be interpreted as granting rights to **BB保你大** or any other third-party copyrighted material.

---

## No Affiliation

This is an independent technical project.

It is not affiliated with, endorsed by, sponsored by, or officially associated with the creators, producers, broadcasters, distributors, licensors, rights holders, HKAnime, Real-ESRGAN, FFmpeg, or other third parties referenced in this documentation.

References to third-party projects, websites, programme names, and trademarks are included solely to document the tools, source provenance, and methodology involved in the project.

---

# Credits

## Real-ESRGAN

AI super-resolution in this project uses **Real-ESRGAN**, specifically the `realesr-animevideov3` model for the primary remaster.

Real-ESRGAN is developed and maintained by its upstream project and contributors.

- **Official repository:** [xinntao/Real-ESRGAN](https://github.com/xinntao/Real-ESRGAN/)
- **Research paper:** [Real-ESRGAN: Training Real-World Blind Super-Resolution with Pure Synthetic Data](https://arxiv.org/abs/2107.10833)

Real-ESRGAN binaries and pretrained model files are not distributed as part of this repository.

## FFmpeg

**FFmpeg** and **FFprobe** are used for:

- source inspection
- frame extraction
- image resizing
- video encoding
- audio stream copying
- metadata handling
- output verification

FFmpeg is an independent third-party project and is not distributed as part of this repository.

---

# Documentation

- **[Usage Guide](./USAGE.md)** — complete instructions for the four primary PowerShell scripts
- **[Future Upscaling](./FUTURE-UPSCALING.md)** — experimental 2K, 4K, and 8K strategy
- **[Real-ESRGAN Reference](../Real-ESRGAN/)** — local Real-ESRGAN reference documentation

---

## Primary Remaster Summary

```text
Series:             BB保你大
Episodes:           52

Source:             Original SD
Typical Source:     640×480 / 4:3 / 24 fps

AI Model:           Real-ESRGAN realesr-animevideov3
AI Scale:           4×

AI Intermediate:    Typically 2560×1920
Final Resolution:   1440×1080
Aspect Ratio:       4:3

Video:              HEVC / H.265
Encoder:            x265
CRF:                20
Preset:             slow
Pixel Format:       yuv420p

Frame Rate:         Original preserved
Interpolation:      None

Audio:              Original Cantonese AAC
Audio Re-encoding:  None
Language Tag:       yue

Remaster Year:      2026
```

**Primary Remaster:** `1440×1080` · 4:3 · HEVC/H.265 · original 24 fps source timing preserved · original Cantonese AAC · Real-ESRGAN AnimeVideoV3 ×4 · 2026
