# AI Upscale

A collection of practical AI-assisted video restoration and upscaling workflows for older animation and other low-resolution video content.

This repository documents experiments using **Real-ESRGAN**, **FFmpeg**, **FFprobe**, **PowerShell**, and **ChatGPT** to analyse older video sources, determine whether they may benefit from AI restoration, and build repeatable processing workflows for them.

The project started from a simple question:

> **Can older low-resolution animation be made more enjoyable on modern displays without unnecessarily changing its original presentation?**

So far, the answer has often been **yes — but every source is different**.

AI upscaling is not a substitute for a genuine higher-quality master, and it cannot recreate information that never existed in the available source. However, for older material where only low-resolution copies are available, AI restoration can be an interesting and worthwhile technique to experiment with.

---

# Projects

This repository contains multiple restoration projects.

Each project has its **own folder, documentation, processing strategy, and settings** because different sources require different treatment.

Current and ongoing projects include:

- **[BB保你大](./BB保你大/)** — 52-episode Cantonese-dubbed animation; completed primary 1440×1080 AI remaster workflow
- **粵語動畫 神鵰俠侶** — Cantonese-dubbed animation restoration and 1080p upscaling experiments
- **成語動畫廊** — restoration and AI upscaling of older animation material
- **孤星淚** — restoration experiments using source analysis and selective AI processing
- **Other older animation and video sources** — ongoing testing and experimentation

Additional project folders and documentation will be added as workflows are tested and refined.

---

# General Workflow

Although each project may use a different restoration strategy, they all begin with the same principle:

> **Analyse the source before deciding to upscale it.**

The general workflow is:

```text
Source Video
     │
     ▼
Scan-Videos.ps1
     │
     ▼
FFprobe Technical Analysis
     │
     ├── Resolution
     ├── Aspect Ratio
     ├── Frame Rate
     ├── Field Order
     ├── Video Codec
     ├── Pixel Format
     ├── Video Bitrate
     ├── Audio Codec
     ├── Audio Channels
     └── Duration
     │
     ▼
Candidate Assessment
     │
     ├── AI Upscale Candidate
     ├── Further Inspection Required
     └── Upscaling May Not Be Necessary
     │
     ▼
Project-Specific Restoration Strategy
     │
     ▼
Test / Compare
     │
     ▼
Full Processing
     │
     ▼
Verification
     │
     ▼
Archive / Playback
```

The intention is **not to blindly run every video through an AI model**.

The source is inspected first, and the restoration approach is then selected based on what is actually present in the file.

---

# `Scan-Videos.ps1`

`Scan-Videos.ps1` is the common starting point for the projects in this repository.

The script uses **FFprobe** to inspect video files and generate a technical report that can be used to identify potential AI-upscaling candidates.

Typical information collected includes:

| Property | Purpose |
|---|---|
| Resolution | Determines the source raster and potential upscale requirement |
| SAR / DAR | Identifies the intended aspect ratio |
| Frame Rate | Helps preserve original source timing |
| Field Order | Identifies progressive or interlaced material |
| Video Codec | Documents the source encoding |
| Pixel Format | Helps identify source characteristics |
| Colour Information | Records available colour-space metadata |
| Video Bitrate | Helps identify heavily compressed sources |
| Audio Codec | Documents the original audio |
| Audio Channels | Identifies mono/stereo/multichannel audio |
| Audio Sample Rate | Records source audio properties |
| Duration | Helps verify complete episodes |
| File Size | Useful for identifying unusual files |
| Candidate | Indicates potential suitability for AI processing |
| Decision | Provides an initial processing classification |
| Reason | Explains why the source received that classification |

For example, older animation may be identified as a potential candidate when characteristics such as these are found:

```text
Low source resolution
        +
Low / very low video bitrate
        +
Older compressed video
        +
Progressive animation source
        ↓
Potential AI Restoration Candidate
```

The scan is an **assessment tool**, not a guarantee that AI processing will improve a video.

Visual testing is still important.

---

# Why Scan First?

Resolution alone does not determine whether a video should be AI-upscaled.

Two files can both be:

```text
640×480
```

while having substantially different quality.

One might be a relatively clean encode from a good source.

Another might contain:

- heavy compression
- ringing
- blocking
- blurred line art
- scaling artifacts
- noise
- poor colour reproduction
- previous-generation encoding damage

Likewise, a file labelled `1080p` is not automatically better than a good SD source.

For that reason, the workflow attempts to understand the source before choosing the restoration method.

---

# Project-Specific Strategies

There is deliberately **no single universal upscale script** for every piece of content.

Different material may require different approaches.

A project might use:

```text
Source
   ↓
Real-ESRGAN ×4
   ↓
Lanczos resize
   ↓
1080p master
```

while another may require:

```text
Source
   ↓
Frame analysis
   ↓
Selective restoration
   ↓
Comparison with original
   ↓
Use restored frame only where beneficial
```

Another source might require consideration of:

- deinterlacing
- denoising
- cropping
- aspect-ratio correction
- different Real-ESRGAN models
- different AI scale factors
- different final resolutions
- different HEVC encoding settings
- preservation of multiple audio tracks
- subtitles
- unusual source frame rates

Each project folder therefore documents the strategy used for that particular source.

---

# AI Upscaling Is Worth Experimenting With

Older animation can be particularly interesting for AI restoration.

Traditional resizing takes existing pixels and mathematically enlarges them:

```text
SD
 ↓
Traditional Scaling
 ↓
Larger SD Image
```

AI super-resolution attempts to reconstruct a higher-resolution representation based on patterns learned by the model:

```text
SD
 ↓
AI Super-Resolution
 ↓
Reconstructed Higher-Resolution Image
```

For animation, this can sometimes improve the appearance of:

- character outlines
- line art
- flat-colour boundaries
- background artwork
- text
- edges
- compressed details

The results depend heavily on the source and the model.

AI processing can also introduce unwanted changes such as:

- invented detail
- over-sharpening
- altered line work
- ringing
- unstable detail between frames
- changed textures
- exaggerated compression artifacts

For this reason:

> **AI-upscaled does not mean objectively better.**

Testing and comparison remain important parts of every workflow.

---

# Preservation Philosophy

The guiding principle of this repository is:

> **Preserve the source, create the remaster separately, and document how the remaster was produced.**

A typical relationship is:

```text
Best Available Source
        │
        ├───────────────> Preserve
        │
        ▼
AI Restoration
        │
        ▼
Remastered Master
```

The source should not be overwritten.

Where the provenance of an original production or broadcast master is unknown, project documentation uses terms such as:

```text
Best Available Source
```

or:

```text
Best Available SD Source
```

rather than claiming that a particular web encode or copy is the original master.

---

# Future Remasters

Whenever the best available source remains accessible, future restoration attempts should preferably start from that source again.

Preferred:

```text
                     ┌──> Current Remaster
                     │
Best Available ──────┼──> Future Remaster A
Source               │
                     ├──> Future Remaster B
                     │
                     └──> Future Remaster C
```

Rather than:

```text
Source
   ↓
AI Remaster
   ↓
AI Remaster
   ↓
AI Remaster
```

Repeatedly processing AI-generated detail can compound artifacts and cause the result to move progressively further away from the available source.

However, if an earlier source is no longer available and an AI remaster becomes the **best available surviving source**, further restoration can still be attempted.

Such a result should simply be documented accurately as a:

```text
Derived Remaster
```

or:

```text
Second-Generation AI Remaster
```

The general rule is:

> **Use the earliest and highest-quality available generation, and document its provenance accurately.**

---

# Original Frame Rate and Aspect Ratio

Where practical, projects in this repository attempt to preserve the presentation characteristics of their source.

This generally means avoiding unnecessary:

- frame interpolation
- 24/25/30 fps → 60 fps conversion
- widescreen stretching
- cropping
- audio replacement

For example, a 4:3 source intended for a 1080-line output may use:

```text
1440×1080
```

rather than stretching the active picture to:

```text
1920×1080
```

Modern players can pillarbox 4:3 material appropriately on a 16:9 display.

Individual project documentation records any exceptions.

---

# Audio Preservation

AI restoration in these projects primarily targets the **video image**.

Where possible, the original audio stream from the source file is preserved without re-encoding:

```text
Source Video
    │
    ├── Video → AI restoration / re-encoding
    │
    └── Audio ───────────────────────┐
                                     │
                                     ▼
                              Final Remaster
```

This is particularly important for projects involving older Cantonese-dubbed animation where the audio itself may be difficult to replace.

---

# ChatGPT-Assisted Development

**ChatGPT has been used extensively during the development of this repository.**

It has assisted with areas including:

- analysing FFprobe output
- interpreting source characteristics
- designing PowerShell workflows
- developing and debugging scripts
- troubleshooting FFmpeg
- troubleshooting Real-ESRGAN
- comparing restoration strategies
- selecting candidate processing methods
- calculating storage requirements
- designing restart and recovery logic
- metadata planning
- SHA-256 integrity workflows
- documentation
- preservation strategy
- evaluating future 2K / 4K / 8K experiments

The intention is not to treat AI-generated recommendations as automatically correct.

Instead, ChatGPT is used as a **technical assistant during an iterative workflow**:

```text
Inspect
   ↓
Discuss / Analyse
   ↓
Build
   ↓
Test
   ↓
Compare
   ↓
Find Problems
   ↓
Revise
   ↓
Test Again
   ↓
Document
```

Actual video outputs are visually inspected and technical results are verified using tools such as FFmpeg and FFprobe.

---

# Tools

The workflows documented in this repository primarily use:

### FFmpeg / FFprobe

Used for:

- source inspection
- frame extraction
- stream inspection
- image resizing
- video encoding
- audio stream copying
- metadata handling
- output verification

### Real-ESRGAN

Used for AI-based image restoration and super-resolution.

Official project:

**[xinntao/Real-ESRGAN](https://github.com/xinntao/Real-ESRGAN/)**

Research paper:

**[Real-ESRGAN: Training Real-World Blind Super-Resolution with Pure Synthetic Data](https://arxiv.org/abs/2107.10833)**

### PowerShell

Used to automate:

- scanning
- episode detection
- batch processing
- restart/recovery
- verification
- metadata operations
- integrity checking

### ChatGPT

Used as an AI-assisted development, troubleshooting, analysis, and documentation tool throughout the project.

---

# Repository Structure

The repository is organised around a common scanning workflow followed by project-specific processing.

```text
ai-upscale/
│
├── README.md
│
├── Scan-Videos.ps1
│
├── Real-ESRGAN/
│   └── README.md
│
├── BB保你大/
│   ├── README.md
│   ├── USAGE.md
│   ├── FUTURE-UPSCALING.md
│   ├── 01-Upscale.ps1
│   ├── 02-Metadata.ps1
│   ├── 03-SHA256.ps1
│   ├── 04-Verify-SHA256.ps1
│   └── experimental/
│
├── 粵語動畫 神鵰俠侶/
│   └── ...
│
├── 成語動畫廊/
│   └── ...
│
├── 孤星淚/
│   └── ...
│
└── other projects...
```

Each content folder may use a different workflow depending on the properties and condition of its available source.

---

# Getting Started

A new source should generally begin with:

```text
Scan-Videos.ps1
```

The scan results can then be reviewed to determine whether the material is a potential candidate for restoration.

A typical process is:

```text
1. Keep the best available source unchanged

2. Run Scan-Videos.ps1

3. Review:
   - resolution
   - aspect ratio
   - frame rate
   - field order
   - bitrate
   - codec
   - audio
   - candidate assessment

4. Select representative samples

5. Test one or more restoration approaches

6. Compare against the source

7. Decide whether AI restoration is beneficial

8. Build a project-specific workflow

9. Process the collection

10. Verify and document the result
```

Do not assume that settings from one project are automatically appropriate for another.

---

# What This Project Is Not

This project is not intended to:

- make every old video "4K"
- replace genuine HD or restored masters
- claim AI-generated detail is original detail
- convert everything to 60 fps
- stretch 4:3 material to 16:9
- apply identical processing to every source
- discard the source after creating a remaster

The objective is to explore what modern restoration tools can achieve while keeping the relationship between the available source and the resulting remaster clear.

---

# Disclaimer

This repository documents technical video analysis, restoration, and AI-upscaling workflows.

It contains **scripts, documentation, configuration examples, and processing methodology only**.

Individual project folders may document the provenance and technical characteristics of material used while developing a workflow. Such documentation should not be interpreted as a claim regarding ownership, licensing status, authorization, or redistribution rights of third-party material.

No ownership of third-party programmes, animation, audio, characters, artwork, trademarks, or other copyrighted material is claimed.

The availability of material online does not necessarily grant permission to reproduce, modify, distribute, or otherwise use copyrighted material.

No original or remastered programme episodes are distributed through this repository.

Users are responsible for determining whether their acquisition, processing, storage, modification, publication, or distribution of media complies with applicable law and any relevant licences or permissions.

AI restoration or upscaling does not by itself change the ownership or copyright status of the underlying source material.

---

# Summary

**AI upscaling is worth experimenting with — particularly when working with older animation or other video for which the best available source is low resolution.**

But the workflow should begin with analysis rather than assumptions:

```text
SCAN
  ↓
UNDERSTAND THE SOURCE
  ↓
TEST
  ↓
COMPARE
  ↓
RESTORE
  ↓
VERIFY
  ↓
DOCUMENT
  ↓
PRESERVE
```

Different sources require different strategies.

That is why this repository keeps a common **`Scan-Videos.ps1`** assessment workflow while documenting each restoration project separately.

The goal is not simply to produce a bigger video.

The goal is to determine:

> **How much can we improve the best available source while preserving the characteristics that should remain unchanged?**
