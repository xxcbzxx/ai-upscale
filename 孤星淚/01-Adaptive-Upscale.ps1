# ============================================================
# 孤星淚 / GXL - Adaptive 1080p Remaster
#
# SOURCE:
#   D:\Data\GXL\*.mp4
#
# TEMP WORK:
#   C:\Real-ESRGAN\batch-work-gxl
#
# FINAL:
#   D:\Data\GXL\Upscaled
#
# Rules:
#   - Original audio stream(s) COPY ONLY
#   - Preserve source playback frame rate
#   - 1920x1080 final
#   - HEVC x265 slow CRF18
#   - 1080p sources are sampled first
#   - Lower-resolution sources automatically get AI
#   - Real-ESRGAN work paths remain ASCII-only
# ============================================================


# ------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------

$SourceDir  = "D:\Data\GXL"
$OutputDir  = "D:\Data\GXL\Upscaled"

# IMPORTANT: ASCII-only path for Real-ESRGAN
$WorkRoot   = "C:\Real-ESRGAN\batch-work-gxl"

$RealESRGAN = "C:\Real-ESRGAN\realesrgan-ncnn-vulkan.exe"

# Start/resume episode
$StartEpisode = 1

# Number of test frames spread across each 1080p episode
$SampleCount = 24

# AI batch size for full restoration
# 100 keeps temporary 8K PNG usage much lower than 500.
$ChunkSize = 100

# Work-drive safety limit
$MinimumFreeGB = 60

# ------------------------------------------------------------
# AI decision thresholds
#
# If BOTH conditions are met, AI is considered negligible:
#
#   SSIM >= 0.995
#   PSNR >= 45 dB
#
# In that case:
#   skip full AI
#
# Otherwise:
#   full AI restoration
# ------------------------------------------------------------

$SkipAI_SSIM = 0.995
$SkipAI_PSNR = 45.0


# ============================================================
# HELPERS
# ============================================================

function Convert-RationalToDouble {

    param(
        [string]$Value
    )

    if ($Value -match '^(-?\d+(?:\.\d+)?)/(-?\d+(?:\.\d+)?)$') {

        $Num = [double]$matches[1]
        $Den = [double]$matches[2]

        if ($Den -eq 0) {
            return 0
        }

        return $Num / $Den
    }

    return [double]$Value
}


function Get-FreeGB {

    param(
        [string]$Path
    )

    $Drive = (Split-Path $Path -Qualifier).TrimEnd(':')

    return [math]::Round(
        (Get-PSDrive $Drive).Free / 1GB,
        2
    )
}


# ============================================================
# BASIC VALIDATION
# ============================================================

if (-not (Test-Path $SourceDir)) {
    throw "Source directory does not exist: $SourceDir"
}

if (-not (Test-Path $RealESRGAN)) {
    throw "Real-ESRGAN executable not found: $RealESRGAN"
}

New-Item `
    -ItemType Directory `
    -Force `
    -Path $OutputDir `
    | Out-Null

New-Item `
    -ItemType Directory `
    -Force `
    -Path $WorkRoot `
    | Out-Null


# ============================================================
# FIND EPISODES
# ============================================================

$Files = Get-ChildItem `
    $SourceDir `
    -Filter "*.mp4" `
    -File |
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


Write-Host ""
Write-Host "============================================================"
Write-Host " GXL Adaptive 1080p Remaster"
Write-Host "============================================================"
Write-Host "Episodes found : $($Files.Count)"
Write-Host "Source         : $SourceDir"
Write-Host "Temporary work : $WorkRoot"
Write-Host "Final output   : $OutputDir"
Write-Host ""
Write-Host "Sample frames  : $SampleCount"
Write-Host "AI chunk size  : $ChunkSize"
Write-Host "Skip-AI SSIM   : $SkipAI_SSIM"
Write-Host "Skip-AI PSNR   : $SkipAI_PSNR dB"
Write-Host "============================================================"
Write-Host ""


# ============================================================
# EPISODE LOOP
# ============================================================

foreach ($File in $Files) {

    if ($File.BaseName -notmatch '^(\d+)-') {
        continue
    }

    $Episode = [int]$matches[1]

    $EpisodeTag = "EP{0:D2}" -f $Episode


    # --------------------------------------------------------
    # ASCII-only temporary paths
    # --------------------------------------------------------

    $EpisodeWork = Join-Path $WorkRoot $EpisodeTag

    $SampleOrig  = Join-Path $EpisodeWork "sample-original"
    $SampleAI    = Join-Path $EpisodeWork "sample-ai"
    $Sample1080  = Join-Path $EpisodeWork "sample-ai-1080"

    $Frames      = Join-Path $EpisodeWork "source-frames"

    $ChunkIn     = Join-Path $EpisodeWork "chunk-in"
    $ChunkAI     = Join-Path $EpisodeWork "chunk-ai"

    $FinalFrames = Join-Path $EpisodeWork "final-frames"


    # --------------------------------------------------------
    # Final file
    # --------------------------------------------------------

    $OutputFile = Join-Path `
        $OutputDir `
        "$($File.BaseName)-Remastered-1080p.mkv"


    Write-Host ""
    Write-Host "============================================================"
    Write-Host " Processing $EpisodeTag"
    Write-Host " $($File.Name)"
    Write-Host "============================================================"
    Write-Host ""


    # --------------------------------------------------------
    # Skip existing completed file
    # --------------------------------------------------------

    if (Test-Path $OutputFile) {

        Write-Host "$EpisodeTag already exists. Skipping." `
            -ForegroundColor Yellow

        continue
    }


    # --------------------------------------------------------
    # C: space check
    # --------------------------------------------------------

    $FreeGB = Get-FreeGB $WorkRoot

    Write-Host "C: free space: $FreeGB GB"

    if ($FreeGB -lt $MinimumFreeGB) {

        Write-Error `
            "$EpisodeTag not started - only $FreeGB GB free on work drive."

        break
    }


    # ========================================================
    # PROBE ORIGINAL VIDEO
    # ========================================================

    $ProbeJSON = ffprobe `
        -v error `
        -select_streams v:0 `
        -count_frames `
        -show_entries `
        "stream=width,height,avg_frame_rate,r_frame_rate,nb_read_frames,sample_aspect_ratio,display_aspect_ratio:format=duration" `
        -of json `
        "$($File.FullName)"


    if ($LASTEXITCODE -ne 0) {

        Write-Error "ffprobe failed for $EpisodeTag"
        break
    }


    $Probe = $ProbeJSON | ConvertFrom-Json
    $Video = $Probe.streams[0]


    $Width          = [int]$Video.width
    $Height         = [int]$Video.height

    # IMPORTANT:
    # use average playback rate, NOT r_frame_rate.
    $FrameRateRaw   = $Video.avg_frame_rate

    $ReportedRate   = $Video.r_frame_rate

    $TotalFrames    = [int64]$Video.nb_read_frames

    $SourceDuration = [double]$Probe.format.duration

    $SourceFPS      = Convert-RationalToDouble $FrameRateRaw


    if ($SourceFPS -le 0) {

        Write-Error "Invalid source FPS for $EpisodeTag"
        break
    }


    if ($TotalFrames -le 0) {

        Write-Error "Invalid source frame count for $EpisodeTag"
        break
    }


    Write-Host "Resolution       : ${Width}x${Height}"
    Write-Host "avg_frame_rate   : $FrameRateRaw"
    Write-Host "r_frame_rate     : $ReportedRate"
    Write-Host "Playback FPS     : $SourceFPS"
    Write-Host "Frames           : $TotalFrames"
    Write-Host "Duration         : $SourceDuration sec"


    # Protection against the earlier 250fps problem

    if ($SourceFPS -gt 120) {

        Write-Error `
            "Suspicious playback FPS ($SourceFPS). Refusing to process."

        break
    }


    # ========================================================
    # PROBE ORIGINAL AUDIO
    # ========================================================

    $SourceAudioJSON = ffprobe `
        -v error `
        -select_streams a `
        -show_entries `
        "stream=codec_name,sample_rate,channels,channel_layout" `
        -of json `
        "$($File.FullName)"


    $SourceAudio = `
        ($SourceAudioJSON | ConvertFrom-Json).streams


    Write-Host ""
    Write-Host "Audio streams: $($SourceAudio.Count)"

    foreach ($Audio in $SourceAudio) {

        Write-Host (
            "  {0}, {1} Hz, {2} channels" -f `
            $Audio.codec_name,
            $Audio.sample_rate,
            $Audio.channels
        )
    }


    # ========================================================
    # CLEAN EPISODE WORKSPACE
    # ========================================================

    Remove-Item `
        $EpisodeWork `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue


    New-Item `
        -ItemType Directory `
        -Force `
        -Path $EpisodeWork `
        | Out-Null


    # ========================================================
    # DECIDE WHETHER AI IS NECESSARY
    # ========================================================

    $UseAI = $false

    $AverageSSIM = $null
    $AveragePSNR = $null


    # --------------------------------------------------------
    # Lower than 1920x1080?
    #
    # Force AI automatically.
    # This catches EP23/24/31/32.
    # --------------------------------------------------------

    if (($Width -lt 1920) -or ($Height -lt 1080)) {

        Write-Host ""
        Write-Host "Source is below 1920x1080." `
            -ForegroundColor Yellow

        Write-Host "Full AI restoration will be used." `
            -ForegroundColor Yellow

        $UseAI = $true
    }


    # ========================================================
    # 1080p SAMPLE TEST
    # ========================================================

    else {

        Write-Host ""
        Write-Host "1080p source detected."
        Write-Host "Testing whether AI materially changes the image..."


        New-Item `
            -ItemType Directory `
            -Force `
            -Path $SampleOrig,$SampleAI,$Sample1080 `
            | Out-Null


        # ----------------------------------------------------
        # Extract samples evenly throughout episode
        # ----------------------------------------------------

        for ($s = 1; $s -le $SampleCount; $s++) {

            # Avoid very beginning/end.
            #
            # Example with 24 samples:
            # about 1/25, 2/25 ... 24/25 through episode.

            $Fraction = `
                $s / ($SampleCount + 1)

            $Timestamp = `
                $SourceDuration * $Fraction


            $SampleName = `
                "sample_{0:D3}.png" -f $s

            $SamplePath = `
                Join-Path $SampleOrig $SampleName


            ffmpeg `
                -hide_banner `
                -loglevel error `
                -y `
                -ss $Timestamp `
                -i "$($File.FullName)" `
                -map 0:v:0 `
                -frames:v 1 `
                "$SamplePath"


            if ($LASTEXITCODE -ne 0) {

                Write-Error `
                    "Sample extraction failed at sample $s."

                break 2
            }
        }


        # ----------------------------------------------------
        # Real-ESRGAN sample set
        # ----------------------------------------------------

        Write-Host ""
        Write-Host "AI-processing $SampleCount sample frames..."


        & $RealESRGAN `
            -i "$SampleOrig" `
            -o "$SampleAI" `
            -n realesr-animevideov3 `
            -s 4 `
            -f png


        if ($LASTEXITCODE -ne 0) {

            Write-Error `
                "Real-ESRGAN sample test failed."

            break
        }


        # ----------------------------------------------------
        # Reduce sample AI results back to 1920x1080
        # ----------------------------------------------------

        Write-Host `
            "Reducing AI samples back to 1920x1080..."


        $AISamples = `
            Get-ChildItem "$SampleAI\*.png" |
            Sort-Object Name


        foreach ($AISample in $AISamples) {

            $DownscaledPath = `
                Join-Path `
                $Sample1080 `
                $AISample.Name


            ffmpeg `
                -hide_banner `
                -loglevel error `
                -y `
                -i "$($AISample.FullName)" `
                -vf `
                "scale=1920:1080:flags=lanczos,setsar=1" `
                "$DownscaledPath"


            if ($LASTEXITCODE -ne 0) {

                Write-Error `
                    "Sample downscale failed: $($AISample.Name)"

                break 2
            }
        }


        # ====================================================
        # SSIM COMPARISON
        # ====================================================

        Write-Host ""
        Write-Host "Calculating SSIM..."


        $SSIMOutput = & ffmpeg `
            -hide_banner `
            -framerate 1 `
            -i "$SampleOrig\sample_%03d.png" `
            -framerate 1 `
            -i "$Sample1080\sample_%03d.png" `
            -lavfi "ssim" `
            -f null NUL `
            2>&1


        $SSIMText = `
            $SSIMOutput -join "`n"


        $SSIMMatch = `
            [regex]::Match(
                $SSIMText,
                'All:([0-9.]+)'
            )


        if (-not $SSIMMatch.Success) {

            Write-Error `
                "Could not parse SSIM result."

            break
        }


        $AverageSSIM = `
            [double]$SSIMMatch.Groups[1].Value


        # ====================================================
        # PSNR COMPARISON
        # ====================================================

        Write-Host "Calculating PSNR..."


        $PSNROutput = & ffmpeg `
            -hide_banner `
            -framerate 1 `
            -i "$SampleOrig\sample_%03d.png" `
            -framerate 1 `
            -i "$Sample1080\sample_%03d.png" `
            -lavfi "psnr" `
            -f null NUL `
            2>&1


        $PSNRText = `
            $PSNROutput -join "`n"


        $PSNRMatch = `
            [regex]::Match(
                $PSNRText,
                'average:([0-9.]+)'
            )


        if (-not $PSNRMatch.Success) {

            Write-Error `
                "Could not parse PSNR result."

            break
        }


        $AveragePSNR = `
            [double]$PSNRMatch.Groups[1].Value


        Write-Host ""
        Write-Host "============================================"
        Write-Host " AI SAMPLE COMPARISON"
        Write-Host "============================================"
        Write-Host "SSIM : $AverageSSIM"
        Write-Host "PSNR : $AveragePSNR dB"
        Write-Host ""


        # ----------------------------------------------------
        # Decision
        # ----------------------------------------------------

        if (
            ($AverageSSIM -ge $SkipAI_SSIM) -and
            ($AveragePSNR -ge $SkipAI_PSNR)
        ) {

            Write-Host `
                "AI difference is negligible." `
                -ForegroundColor Green

            Write-Host `
                "Full AI processing will be SKIPPED." `
                -ForegroundColor Green

            $UseAI = $false
        }
        else {

            Write-Host `
                "AI materially changes the picture." `
                -ForegroundColor Yellow

            Write-Host `
                "Full AI restoration will be used." `
                -ForegroundColor Yellow

            $UseAI = $true
        }


        # Samples no longer needed.

        Remove-Item `
            $SampleOrig,$SampleAI,$Sample1080 `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
    }


    # ========================================================
    # PATH A:
    # DIRECT REMASTER
    #
    # No AI.
    #
    # Decode original video normally and re-encode HEVC.
    # This retains the original video timing directly.
    # ========================================================

    if (-not $UseAI) {

        Write-Host ""
        Write-Host "============================================================"
        Write-Host " DIRECT REMASTER PATH"
        Write-Host "============================================================"

        Write-Host "No unnecessary AI upscale/downscale."
        Write-Host "Video -> HEVC CRF18"
        Write-Host "Audio -> COPY"


        ffmpeg `
            -hide_banner `
            -y `
            -i "$($File.FullName)" `
            -map 0:v:0 `
            -map 0:a? `
            -map_metadata 0 `
            -c:v libx265 `
            -preset slow `
            -crf 18 `
            -pix_fmt yuv420p `
            -c:a copy `
            "$OutputFile"


        if ($LASTEXITCODE -ne 0) {

            Write-Error `
                "Direct remaster failed for $EpisodeTag"

            break
        }
    }


    # ========================================================
    # PATH B:
    # FULL AI RESTORATION
    # ========================================================

    else {

        Write-Host ""
        Write-Host "============================================================"
        Write-Host " FULL AI RESTORATION PATH"
        Write-Host "============================================================"


        New-Item `
            -ItemType Directory `
            -Force `
            -Path $Frames,$FinalFrames `
            | Out-Null


        # ----------------------------------------------------
        # Extract complete source frame sequence
        # ----------------------------------------------------

        Write-Host ""
        Write-Host "Extracting source frames..."


        ffmpeg `
            -hide_banner `
            -loglevel warning `
            -y `
            -i "$($File.FullName)" `
            -map 0:v:0 `
            -fps_mode passthrough `
            "$Frames\frame_%08d.png"


        if ($LASTEXITCODE -ne 0) {

            Write-Error `
                "Frame extraction failed for $EpisodeTag"

            break
        }


        $ExtractedCount = `
            (Get-ChildItem "$Frames\*.png").Count


        Write-Host `
            "Extracted $ExtractedCount frames."


        if ($ExtractedCount -ne $TotalFrames) {

            Write-Error (
                "Frame mismatch. " +
                "Source=$TotalFrames Extracted=$ExtractedCount"
            )

            break
        }


        # ----------------------------------------------------
        # Process source PNGs in chunks
        #
        # Each completed source PNG is deleted after its
        # restored 1080p counterpart is produced.
        #
        # This keeps C: usage much lower.
        # ----------------------------------------------------

        $AllFrames = `
            Get-ChildItem "$Frames\*.png" |
            Sort-Object Name


        for (
            $Start = 0;
            $Start -lt $AllFrames.Count;
            $Start += $ChunkSize
        ) {

            $End = [math]::Min(
                $Start + $ChunkSize - 1,
                $AllFrames.Count - 1
            )


            $ChunkFrames = `
                $AllFrames[$Start..$End]


            $ExpectedChunkCount = `
                $End - $Start + 1


            Write-Host ""
            Write-Host "------------------------------------------------------------"
            Write-Host (
                "AI frames {0}-{1} / {2}" -f `
                ($Start + 1),
                ($End + 1),
                $TotalFrames
            )
            Write-Host "------------------------------------------------------------"


            Remove-Item `
                $ChunkIn,$ChunkAI `
                -Recurse `
                -Force `
                -ErrorAction SilentlyContinue


            New-Item `
                -ItemType Directory `
                -Force `
                -Path $ChunkIn,$ChunkAI `
                | Out-Null


            # ------------------------------------------------
            # COPY current source chunk
            # ------------------------------------------------

            $ChunkFrames |
                Copy-Item `
                    -Destination $ChunkIn


            # ------------------------------------------------
            # AI x4
            # ------------------------------------------------

            & $RealESRGAN `
                -i "$ChunkIn" `
                -o "$ChunkAI" `
                -n realesr-animevideov3 `
                -s 4 `
                -f png


            if ($LASTEXITCODE -ne 0) {

                Write-Error (
                    "Real-ESRGAN failed starting at " +
                    "frame $($Start + 1)"
                )

                break 2
            }


            $AIFrames = `
                Get-ChildItem "$ChunkAI\*.png" |
                Sort-Object Name


            if (
                $AIFrames.Count `
                -ne `
                $ExpectedChunkCount
            ) {

                Write-Error (
                    "AI frame mismatch. " +
                    "Expected=$ExpectedChunkCount " +
                    "Actual=$($AIFrames.Count)"
                )

                break 2
            }


            # ------------------------------------------------
            # Immediately return AI frames to 1080p
            # ------------------------------------------------

            foreach ($AIFrame in $AIFrames) {

                $FinalPath = `
                    Join-Path `
                    $FinalFrames `
                    $AIFrame.Name


                ffmpeg `
                    -hide_banner `
                    -loglevel error `
                    -y `
                    -i "$($AIFrame.FullName)" `
                    -vf `
                    "scale=1920:1080:flags=lanczos,setsar=1" `
                    "$FinalPath"


                if ($LASTEXITCODE -ne 0) {

                    Write-Error (
                        "1080p conversion failed: " +
                        "$($AIFrame.Name)"
                    )

                    break 3
                }
            }


            # ------------------------------------------------
            # Delete original PNGs that have now been restored.
            #
            # We don't need them anymore.
            # ------------------------------------------------

            foreach ($SourceFrame in $ChunkFrames) {

                Remove-Item `
                    $SourceFrame.FullName `
                    -Force
            }


            # Delete temporary AI x4 data

            Remove-Item `
                $ChunkIn,$ChunkAI `
                -Recurse `
                -Force


            $CompletedFrames = `
                (Get-ChildItem "$FinalFrames\*.png").Count


            Write-Host (
                "Completed: $CompletedFrames / $TotalFrames"
            )


            $FreeGB = Get-FreeGB $WorkRoot

            Write-Host `
                "C: free: $FreeGB GB"


            if ($FreeGB -lt $MinimumFreeGB) {

                Write-Error `
                    "Stopping: only $FreeGB GB free on C:."

                break 2
            }
        }


        # ----------------------------------------------------
        # Verify final image count
        # ----------------------------------------------------

        $RestoredCount = `
            (Get-ChildItem "$FinalFrames\*.png").Count


        if ($RestoredCount -ne $TotalFrames) {

            Write-Error (
                "Restoration incomplete. " +
                "Source=$TotalFrames Restored=$RestoredCount"
            )

            break
        }


        # ----------------------------------------------------
        # Reconstruct video at ORIGINAL playback cadence
        # ----------------------------------------------------

        Write-Host ""
        Write-Host "Encoding restored video..."
        Write-Host "Frame rate : $FrameRateRaw"
        Write-Host "Audio      : COPY"


        ffmpeg `
            -hide_banner `
            -y `
            -framerate "$FrameRateRaw" `
            -i "$FinalFrames\frame_%08d.png" `
            -i "$($File.FullName)" `
            -map 0:v:0 `
            -map 1:a? `
            -map_metadata 1 `
            -c:v libx265 `
            -preset slow `
            -crf 18 `
            -pix_fmt yuv420p `
            -c:a copy `
            "$OutputFile"


        if ($LASTEXITCODE -ne 0) {

            Write-Error `
                "AI final encoding failed for $EpisodeTag"

            break
        }
    }


    # ========================================================
    # STRICT FINAL VERIFICATION
    # ========================================================

    Write-Host ""
    Write-Host "Performing strict verification..."


    $OutProbeJSON = ffprobe `
        -v error `
        -select_streams v:0 `
        -count_frames `
        -show_entries `
        "stream=width,height,avg_frame_rate,nb_read_frames:format=duration" `
        -of json `
        "$OutputFile"


    if ($LASTEXITCODE -ne 0) {

        Write-Error "Final ffprobe failed."
        break
    }


    $OutProbe = `
        $OutProbeJSON |
        ConvertFrom-Json


    $OutVideo = `
        $OutProbe.streams[0]


    $OutputFPSRaw = `
        $OutVideo.avg_frame_rate


    $OutputFPS = `
        Convert-RationalToDouble `
        $OutputFPSRaw


    $OutputFrames = `
        [int64]$OutVideo.nb_read_frames


    $OutputDuration = `
        [double]$OutProbe.format.duration


    # ========================================================
    # VERIFY AUDIO
    # ========================================================

    $OutputAudioJSON = ffprobe `
        -v error `
        -select_streams a `
        -show_entries `
        "stream=codec_name,sample_rate,channels,channel_layout" `
        -of json `
        "$OutputFile"


    $OutputAudio = `
        ($OutputAudioJSON | ConvertFrom-Json).streams


    Write-Host ""
    Write-Host "SOURCE"
    Write-Host " FPS      : $FrameRateRaw ($SourceFPS)"
    Write-Host " Frames   : $TotalFrames"
    Write-Host " Duration : $SourceDuration"

    Write-Host ""
    Write-Host "OUTPUT"
    Write-Host " FPS      : $OutputFPSRaw ($OutputFPS)"
    Write-Host " Frames   : $OutputFrames"
    Write-Host " Duration : $OutputDuration"


    # --------------------------------------------------------
    # Frame count
    # --------------------------------------------------------

    if ($OutputFrames -ne $TotalFrames) {

        Write-Error (
            "FINAL FRAME COUNT FAILED. " +
            "Source=$TotalFrames Output=$OutputFrames"
        )

        break
    }


    # --------------------------------------------------------
    # FPS
    # --------------------------------------------------------

    $FPSDifference = `
        [math]::Abs(
            $SourceFPS - $OutputFPS
        )


    if ($FPSDifference -gt 0.01) {

        Write-Error (
            "FINAL FPS FAILED. " +
            "Source=$SourceFPS Output=$OutputFPS"
        )

        break
    }


    # --------------------------------------------------------
    # Duration
    # --------------------------------------------------------

    $DurationDifference = `
        [math]::Abs(
            $SourceDuration - $OutputDuration
        )


    if ($DurationDifference -gt 0.75) {

        Write-Error (
            "FINAL DURATION FAILED. " +
            "Source=$SourceDuration Output=$OutputDuration"
        )

        break
    }


    # --------------------------------------------------------
    # Audio stream count
    # --------------------------------------------------------

    if ($SourceAudio.Count -ne $OutputAudio.Count) {

        Write-Error `
            "AUDIO STREAM COUNT CHANGED."

        break
    }


    # --------------------------------------------------------
    # Audio characteristics
    # --------------------------------------------------------

    for (
        $a = 0;
        $a -lt $SourceAudio.Count;
        $a++
    ) {

        if (
            $SourceAudio[$a].codec_name `
            -ne `
            $OutputAudio[$a].codec_name
        ) {

            Write-Error `
                "Audio codec changed."

            break 2
        }


        if (
            $SourceAudio[$a].sample_rate `
            -ne `
            $OutputAudio[$a].sample_rate
        ) {

            Write-Error `
                "Audio sample rate changed."

            break 2
        }


        if (
            $SourceAudio[$a].channels `
            -ne `
            $OutputAudio[$a].channels
        ) {

            Write-Error `
                "Audio channel count changed."

            break 2
        }
    }


    # ========================================================
    # SUCCESS
    # ========================================================

    $OutputSizeGB = `
        [math]::Round(
            (Get-Item $OutputFile).Length / 1GB,
            3
        )


    Write-Host ""
    Write-Host "============================================================" `
        -ForegroundColor Green

    Write-Host "$EpisodeTag VERIFIED" `
        -ForegroundColor Green


    if ($UseAI) {

        Write-Host `
            "Processing : FULL AI RESTORATION"

    }
    else {

        Write-Host `
            "Processing : DIRECT REMASTER"

        if ($null -ne $AverageSSIM) {

            Write-Host `
                "Test SSIM  : $AverageSSIM"

            Write-Host `
                "Test PSNR  : $AveragePSNR dB"
        }
    }


    Write-Host "Resolution : 1920x1080"
    Write-Host "Codec      : HEVC"
    Write-Host "Frames     : $OutputFrames"
    Write-Host "FPS        : $OutputFPS"
    Write-Host "Audio      : original stream copy"
    Write-Host "Size       : $OutputSizeGB GB"

    Write-Host "============================================================" `
        -ForegroundColor Green


    # ========================================================
    # CLEAN C: WORKSPACE ONLY AFTER VERIFICATION
    # ========================================================

    Remove-Item `
        $EpisodeWork `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue


    Write-Host ""
    Write-Host "$EpisodeTag COMPLETE" `
        -ForegroundColor Green

    Write-Host "$OutputFile"
}


Write-Host ""
Write-Host "============================================================"
Write-Host " GXL adaptive remaster batch finished"
Write-Host "============================================================"
