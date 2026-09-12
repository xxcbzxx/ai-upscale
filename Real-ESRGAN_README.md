# Real-ESRGAN NCNN Vulkan

> [!NOTE]
> This directory contains reference documentation for **Real-ESRGAN**.
> Real-ESRGAN is developed by the upstream Real-ESRGAN project and is not part of this repository.
>
> **Official project:** [xinntao/Real-ESRGAN](https://github.com/xinntao/Real-ESRGAN/)  
> **Research paper:** [Real-ESRGAN: Training Real-World Blind Super-Resolution with Pure Synthetic Data](https://arxiv.org/abs/2107.10833)

## Models

The portable Real-ESRGAN NCNN Vulkan executable provides the following models:

| Model | Purpose |
|---|---|
| `realesr-animevideov3` | Anime/video model — used by this project's remaster workflow |
| `realesrgan-x4plus` | General-purpose ×4 model |
| `realesrgan-x4plus-anime` | Anime-oriented ×4 model |

## Basic Usage

```powershell
.\realesrgan-ncnn-vulkan.exe -i input.jpg -o output.png
```

Specify the AnimeVideoV3 model:

```powershell
.\realesrgan-ncnn-vulkan.exe `
    -i input.jpg `
    -o output.png `
    -n realesr-animevideov3
```

Process a folder at ×2:

```powershell
.\realesrgan-ncnn-vulkan.exe `
    -i input_folder `
    -o output_folder `
    -n realesr-animevideov3 `
    -s 2 `
    -f jpg
```

Process a folder at ×4:

```powershell
.\realesrgan-ncnn-vulkan.exe `
    -i input_folder `
    -o output_folder `
    -n realesr-animevideov3 `
    -s 4 `
    -f jpg
```

---

## Anime Video Workflow

The upstream documentation describes a three-stage workflow:

### 1. Extract Frames

Create `tmp_frames` first, then use FFmpeg to extract the video frames:

```powershell
ffmpeg `
    -i onepiece_demo.mp4 `
    -qscale:v 1 `
    -qmin 1 `
    -qmax 1 `
    -vsync 0 `
    tmp_frames/frame%08d.jpg
```

### 2. AI Upscale

Create `out_frames` first, then process the extracted frames:

```powershell
.\realesrgan-ncnn-vulkan.exe `
    -i tmp_frames `
    -o out_frames `
    -n realesr-animevideov3 `
    -s 2 `
    -f jpg
```

### 3. Reassemble Video

Merge the enhanced frames with the original audio:

```powershell
ffmpeg `
    -i out_frames/frame%08d.jpg `
    -i onepiece_demo.mp4 `
    -map 0:v:0 `
    -map 1:a:0 `
    -c:a copy `
    -c:v libx264 `
    -r 23.98 `
    -pix_fmt yuv420p `
    output_w_audio.mp4
```

> [!IMPORTANT]
> The commands above reproduce the **upstream example workflow**.  
> The [`BB保你大`](../BB保你大/) remaster uses a modified workflow with lossless PNG frames, automatic source frame-rate detection, HEVC/x265 encoding, Cantonese audio metadata, integrity checks, and automatic cleanup.

---

## Portable NCNN Vulkan Build

The executable is portable and includes the required binaries and models. It does not require a CUDA or PyTorch environment.

The NCNN Vulkan implementation may produce slightly different results from the PyTorch implementation. Images can be divided into tiles for processing and subsequently stitched together, which can potentially introduce inconsistencies between tiles.

The executable is based on:

- [Tencent/ncnn](https://github.com/Tencent/ncnn)
- [nihui/realsr-ncnn-vulkan](https://github.com/nihui/realsr-ncnn-vulkan)

---

## Upstream Project

Real-ESRGAN is developed and maintained separately from this repository.

**GitHub:**  
[xinntao/Real-ESRGAN](https://github.com/xinntao/Real-ESRGAN/)

**Paper:**  
[Real-ESRGAN: Training Real-World Blind Super-Resolution with Pure Synthetic Data](https://arxiv.org/abs/2107.10833)

> Please refer to the official Real-ESRGAN repository for current releases,
> pretrained models, licensing information, installation instructions, and
> upstream documentation.

---

## Usage in This Repository

For the **BB保你大 AI Remaster**, the selected configuration was:

```text
Model:          realesr-animevideov3
AI scale:       4×
Source:         SD (typically 640×480)
AI intermediate: typically 2560×1920
Final output:   1440×1080 (4:3)
Frame rate:     Original preserved
Video:          HEVC / H.265
Encoder:        x265 CRF 20, preset slow
Audio:          Original Cantonese AAC
Audio language: yue
Interpolation:  None
```

See the [BB保你大 AI Remaster documentation](../BB保你大/) for the complete workflow.
