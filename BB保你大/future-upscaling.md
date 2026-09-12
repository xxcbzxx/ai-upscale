# Future Upscaling — 2K / 4K / 8K

This document describes possible future higher-resolution versions of the existing **BB保你大 AI Remaster**.

The current remaster is:

```text
Source:          SD, typically 640x480
Current master:  1440x1080
Aspect ratio:    4:3
Frame rate:      Original preserved
AI model:        Real-ESRGAN realesr-animevideov3
AI scale:        4x
Video:           HEVC / H.265
Encoder:         x265 CRF 20, preset slow
Audio:           Original Cantonese AAC
```

The current `1440x1080` files should be considered the main **1080p AI-remastered masters**.

---

# Important Principle

A future 2K, 4K or 8K edition should ideally be generated from the **original SD source**, not by repeatedly upscaling the already-remastered 1080p file.

Preferred:

```text
Original SD source
       │
       ├── AI reconstruction
       │
       └── target-resolution encode
```

Avoid:

```text
Original SD
   ↓
1080p AI remaster
   ↓
4K AI upscale
   ↓
8K AI upscale
```

Repeated AI generations can accumulate:

- artificial detail
- sharpening halos
- line distortion
- texture hallucination
- compression artefacts
- temporal inconsistency

The original source should therefore be retained whenever possible.

---

# Resolution Terminology

For this 4:3 series, output dimensions differ from normal 16:9 UHD resolutions.

A 4:3 image should remain 4:3 rather than being stretched to fill a 16:9 frame.

## Current 1080p Master

```text
1440x1080
```

Aspect ratio:

```text
4:3
```

---

# Possible 2K Output

There are several meanings of "2K".

For preservation purposes, the simplest 4:3 target would be:

```text
2048x1536
```

This maintains:

```text
4:3
```

Example:

```text
640x480
   ↓
AI upscale
   ↓
2048x1536
```

This is approximately a 3.2x enlargement from the original source.

Because Real-ESRGAN AnimeVideoV3 provides x2, x3 and x4 models, a practical workflow could use the x4 model and downscale to 2048x1536.

Example:

```text
640x480
   ↓
Real-ESRGAN x4
   ↓
2560x1920
   ↓
Lanczos
   ↓
2048x1536
```

---

# Possible 4K Output

Standard consumer UHD is:

```text
3840x2160
```

However, that is 16:9.

For native 4:3 content, there are two sensible approaches.

## Option A — Native 4:3 4K-height master

Use:

```text
2880x2160
```

This is exactly 4:3.

```text
2880 / 2160 = 1.3333
```

This is the preferred option if maintaining the original framing.

Example:

```text
640x480
   ↓
AI reconstruction
   ↓
2880x2160
```

## Option B — 3840x2160 with pillarboxing

The active picture remains 4:3:

```text
2880x2160
```

inside a:

```text
3840x2160
```

canvas.

This creates:

```text
480 pixels of pillarbox on each side
```

Conceptually:

```text
┌──────────────────────────────────────┐
│      │                        │      │
│      │                        │      │
│      │      2880x2160         │      │
│      │       4:3 image        │      │
│      │                        │      │
│      │                        │      │
└──────────────────────────────────────┘
        <------ 3840x2160 ------>
```

Normally it is preferable to store the video as:

```text
2880x2160
```

and allow Plex/Jellyfin/the display device to add pillarboxing during playback.

---

# Possible 8K Output

Standard 8K UHD is:

```text
7680x4320
```

Again, this is 16:9.

The equivalent 4:3 frame at 4320 pixels high is:

```text
5760x4320
```

Therefore a native 4:3 8K master would be:

```text
5760x4320
```

This preserves the source aspect ratio exactly.

---

# Recommended Resolution Targets

| Edition | Resolution | Aspect |
|---|---:|---:|
| Current 1080p | `1440x1080` | 4:3 |
| 2K | `2048x1536` | 4:3 |
| 4K | `2880x2160` | 4:3 |
| 8K | `5760x4320` | 4:3 |

These dimensions preserve the original 4:3 frame.

---

# AI Scaling Considerations

The original source is typically only:

```text
640x480
```

The amount of enlargement is therefore substantial.

Approximate scale from the source:

| Target | Scale from 640x480 |
|---|---:|
| 1440x1080 | 2.25x |
| 2048x1536 | 3.2x |
| 2880x2160 | 4.5x |
| 5760x4320 | 9x |

The current Real-ESRGAN x4 intermediate is:

```text
2560x1920
```

This is sufficient for the current:

```text
1440x1080
```

and also suitable for:

```text
2048x1536
```

However, it is **not large enough for a true 2880x2160 output without further scaling**.

---

# 4K Strategy

For 4K, there are several possible approaches.

## Strategy A — Real-ESRGAN x4 + conventional resize

```text
640x480
   ↓
Real-ESRGAN x4
   ↓
2560x1920
   ↓
Lanczos upscale
   ↓
2880x2160
```

Advantages:

- simple
- only one AI generation
- retains current Real-ESRGAN workflow
- avoids applying AI twice

Disadvantages:

- final 2880x2160 contains some conventional enlargement
- little additional real detail beyond the 2560x1920 AI result

This would likely be the safest first 4K experiment.

---

## Strategy B — Two-stage AI scaling

Example:

```text
640x480
   ↓
AI x4
   ↓
2560x1920
   ↓
AI again
   ↓
higher resolution
```

This is **not currently recommended** as the default.

A second AI pass may increase:

- hallucinated detail
- unstable outlines
- temporal inconsistency
- sharpening artefacts

It should only be used after extensive visual testing.

---

## Strategy C — Different higher-resolution AI model

A future model may support larger direct reconstruction or more sophisticated video restoration.

This could provide better results than repeatedly applying the current Real-ESRGAN model.

If a future model is tested, comparisons should include:

- character outlines
- facial detail
- Japanese title cards
- flat-colour regions
- moving objects
- dark scenes
- compression artefacts
- temporal stability between frames

---

# 8K Strategy

8K should be considered experimental for this source.

The original:

```text
640x480
```

would become:

```text
5760x4320
```

This is a:

```text
9x linear enlargement
```

and approximately:

```text
81x as many pixels
```

as the source.

At that point, much of the apparent detail cannot originate from the original SD material.

An 8K version should therefore be considered:

```text
presentation / experimental AI restoration
```

rather than:

```text
recovery of true native 8K detail
```

---

# Storage Requirements

Higher resolutions greatly increase temporary PNG storage.

The current workflow measured approximately:

```text
~3.96 MB per 2560x1920 AI-generated PNG
```

for typical material.

A rough uncompressed pixel comparison is:

| Resolution | Pixels |
|---|---:|
| 640x480 | 307,200 |
| 1440x1080 | 1,555,200 |
| 2560x1920 | 4,915,200 |
| 2880x2160 | 6,220,800 |
| 5760x4320 | 24,883,200 |

A `5760x4320` image contains approximately:

```text
5x
```

as many pixels as the current 2560x1920 AI intermediate.

PNG compression varies by frame, but 8K frame storage could therefore become extremely large.

For approximately 29,500 frames per episode, full-frame 8K processing could require several hundred GB of temporary storage per episode.

Chunk-based processing would likely be mandatory.

---

# Encoding Considerations

Higher-resolution masters should continue using HEVC or a newer efficient codec.

Possible future formats:

```text
HEVC / H.265
AV1
```

HEVC remains broadly compatible with Plex and Jellyfin clients.

AV1 may offer better compression efficiency but requires compatible playback hardware.

---

# Suggested HEVC Starting Points

These are starting points only and should be visually tested.

## 2K

```text
libx265
preset slow
CRF 20
```

## 4K

Possible starting point:

```text
libx265
preset slow
CRF 18-20
```

## 8K

Possible starting point:

```text
libx265
preset slow
CRF 17-20
```

The CRF value should not be selected purely to achieve a target file size.

The objective should remain preserving the AI-generated master with minimal additional compression damage.

---

# Frame Rate

Future remasters should continue to preserve the original temporal structure.

Do not automatically convert:

```text
24 fps
```

into:

```text
30 fps
60 fps
120 fps
```

unless a separate interpolation project is intentionally being created.

The preservation master should retain the original frame rate.

---

# Audio

The original Cantonese audio should continue to be preserved via stream copy:

```text
-c:a copy
```

Audio metadata should remain:

```text
language=yue
title=Cantonese
```

There is no need to re-encode the audio simply because the video resolution changes.

---

# Recommended Future Testing Process

Before producing an entire 52-episode higher-resolution edition:

1. Select one representative episode.
2. Select several difficult scenes.
3. Produce short test clips.
4. Compare at normal playback distance.
5. Compare still frames only as a secondary check.
6. Confirm temporal stability during movement.
7. Check compression efficiency.
8. Confirm Plex/Jellyfin playback and transcoding support.
9. Only then process the complete series.

Suggested comparison:

```text
Original SD
1440x1080 current master
2048x1536 2K
2880x2160 4K
5760x4320 8K
```

---

# Recommended Current Position

For the current source material:

```text
640x480 SD
```

the existing:

```text
1440x1080
```

AI remaster remains the recommended archival master.

A future:

```text
2880x2160
```

4K version may be worthwhile for testing on large modern displays.

An:

```text
5760x4320
```

8K version should currently be considered experimental because the source does not contain enough native spatial information to justify a true 8K reconstruction.

---

# Future Script Layout

If higher-resolution workflows are implemented, they can be added separately:

```text
BB保你大/
├── README.md
├── USAGE.md
├── FUTURE-UPSCALING.md
│
├── 1080p/
│   ├── 01-Upscale.ps1
│   ├── 02-Metadata.ps1
│   ├── 03-SHA256.ps1
│   └── 04-Verify-SHA256.ps1
│
├── 2K/
│   └── 01-Upscale-2K.ps1
│
├── 4K/
│   └── 01-Upscale-4K.ps1
│
└── 8K/
    └── 01-Upscale-8K.ps1
```

Alternatively, the main upscale script could eventually accept:

```powershell
-TargetResolution 1080p
```

or:

```powershell
-TargetResolution 2K
-TargetResolution 4K
-TargetResolution 8K
```

and calculate the correct 4:3 output dimensions automatically.

---

# Preservation Recommendation

Keep the following whenever possible:

```text
Original SD source
        +
1440x1080 AI master
        +
SHA256SUMS.txt
        +
Remaster documentation
```

Future 2K / 4K / 8K editions can then always be regenerated using improved models or processing methods without depending on a previously upscaled generation.
