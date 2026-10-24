
# 孤星淚 — AI Remaster (1080p)

## Overview

This project documents the AI-assisted restoration of **孤星淚** (*Les Misérables: Shōjo Cosette*), covering all **52 episodes**.

The objective is to improve the presentation of the available video sources while preserving the original Cantonese audio, episode content, frame count, and playback duration.

Restoration was performed using a combination of FFmpeg, Real-ESRGAN, automated source analysis, and AI-assisted workflow development with ChatGPT.

**Status: Completed — 52/52 episodes processed and technically verified.**

## Source Material

The available source collection consists of 52 MP4 episodes with varying levels of compression and picture quality.

| Property | Details |
|---|---|
| Episodes | 52 |
| Source container | MP4 |
| Source video | H.264 |
| Source frame rate | Approximately 25 FPS |
| Source audio | AAC, Cantonese |
| Target resolution | 1920 × 1080 |
| Output container | MKV |
| Output video | HEVC / H.265 |
| Output audio | Original audio stream copied |

Some episodes were already encoded at 1080p. However, encoded resolution does not necessarily reflect the amount of genuine image detail available in the source.

## Restoration Strategy

An adaptive workflow was developed to evaluate each episode before committing to full AI processing.

### 1. Source Analysis

FFprobe and FFmpeg were used to inspect source characteristics, including resolution, frame rate, frame count, duration, and audio streams.

### 2. AI Sample Evaluation

Representative samples were processed through Real-ESRGAN and compared with the source using:

- **SSIM** — Structural Similarity Index
- **PSNR** — Peak Signal-to-Noise Ratio

These metrics were used to identify meaningful image changes, rather than as definitive measures of visual quality.

### 3. AI Restoration

Episodes selected for AI processing were restored using:

| Setting | Configuration |
|---|---|
| AI engine | Real-ESRGAN NCNN Vulkan |
| AI model | `realesr-animevideov3` |
| AI scale | 4× |
| Final resolution | 1920 × 1080 |
| GPU | AMD Radeon RX 6800 XT |
| Processing | Frame extraction, chunked AI processing, resizing, encoding |

Chunked processing helped manage temporary storage requirements, especially when 1080p frames were enlarged to 4× their original dimensions.

### 4. Final Encoding

The restored frames were encoded using FFmpeg and libx265.

| Setting | Value |
|---|---|
| Codec | HEVC / H.265 |
| Encoder | libx265 |
| Preset | Slow |
| CRF | 18 |
| Pixel format | yuv420p |
| Frame rate | 25 FPS |
| Audio | Stream copy |
| Container | MKV |

The original audio was copied without intentional re-encoding.

## Verification Results

All 52 completed episodes underwent automated technical verification.

| Test | Result |
|---|---|
| Episode completeness | 52/52 PASS |
| Source/output frame counts | 52/52 PASS |
| Duration tolerance | 52/52 PASS |
| FPS tolerance (±0.01 FPS from 25) | 52/52 PASS |
| Output resolution | 52/52 PASS |
| HEVC video codec | 52/52 PASS |
| AAC audio codec | 52/52 PASS |
| Full video decoding | 52/52 PASS |

The largest observed output FPS deviation from 25 FPS was approximately **0.001319 FPS**.

All output videos successfully passed FFmpeg's full video decoding test.

These checks establish technical consistency and decodability. They do not guarantee that every AI-restored frame is visually perfect or that the audio streams are bit-for-bit identical.

## Known Source Issues

### Episode 03 — 新朋友雪雪

A short sequence around **21:35–21:36** contains visible source corruption affecting the appearance of a puppy.

Several repair approaches were investigated, including temporal interpolation with RIFE and masked reconstruction.

The reconstructed frames introduced noticeable distortion, particularly around the puppy's face and movement.

**Decision:** Preserve the original affected frames rather than introduce unreliable synthetic details.

This follows the project's restoration principle:

> Improve the available source without unnecessarily replacing authentic content with AI-generated reconstruction.

## Limitations

AI upscaling cannot recover information that no longer exists in the available source with guaranteed accuracy.

Compression artifacts, damaged frames, lost texture, and other defects may remain visible after processing.

SSIM and PSNR provide useful diagnostic information but should not be interpreted as proof that an AI-generated result is visually superior.

The goal is a practical, source-conscious enhancement, not a claim of original-studio-quality restoration.

## Tools and Technologies

- [FFmpeg](https://ffmpeg.org/) — Frame extraction, video encoding, stream handling, and verification.
- [Real-ESRGAN](https://github.com/xinntao/Real-ESRGAN) — AI image restoration and super-resolution.
- [Real-ESRGAN NCNN Vulkan](https://github.com/xinntao/Real-ESRGAN-ncnn-vulkan) — Vulkan-accelerated processing.
- [RIFE](https://github.com/hzwer/ECCV2022-RIFE) — Experimental frame interpolation during source repair investigations.
- PowerShell — Batch automation, source analysis, processing, and validation.
- ChatGPT — Workflow development, troubleshooting, script refinement, and restoration analysis.

## Project Files

The following supporting materials can be maintained alongside this README:

- Processing scripts used for the remaster.
- Source-analysis CSV generated by `scan-video.ps1`.
- Final quality assurance CSV (`GXL-Final-QA.csv`).
- Selected before-and-after comparison images.
- Notes describing source defects and restoration decisions.

Large copyrighted video files are not required in the repository to document the restoration workflow.

## Disclaimer

This is an independent, non-commercial, experimental AI restoration project.

All rights to the original animation, characters, music, dialogue, and other copyrighted material remain with their respective rights holders.

The purpose of this repository is to document technical restoration methods, experiments, limitations, and lessons learned.

No ownership of the original animation is claimed.
