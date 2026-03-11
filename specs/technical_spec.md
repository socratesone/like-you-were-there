# Technical Specification
## Time-Place Celebrity Walkthrough Generator (TPCWG)

This document details the updated, template-driven technical workflow.

## 1. High-Level Pipeline
The generation process is now a two-stage workflow orchestrated by a shell script.

1.  **Stage 1: Research & Planning.** A single, powerful LLM call using the `discover_candidates.md` template performs all up-front research. The output is a comprehensive `preproduction.json` file that serves as the master plan for the run.

2.  **Stage 2: Asset Generation.** The main script parses `preproduction.json` and systematically generates all visual assets.
    a. **Image Generation:** Loop through the `candidates` list and generate a still image for each one using the `gen_image.md` template.
    b. **Video Generation:** Loop through the generated images and create transition videos between each pair (`image_i` -> `image_i+1`) using the `gen_video.md` template.

3.  **Stage 3: Final Assembly.** The still images and transition videos are combined into the final MP4.
    a. **Convert Stills:** Each subject image is converted into a short, static video clip.
    b. **Add Overlays:** Text labels (name, age) are added to these static clips.
    c. **Concatenate:** All clips (static subject clips and transition videos) are stitched together in order.

## 2. Stage 1: Research & Planning
- **Trigger:** The `run.sh` script starts by reading the user's `job.json`.
- **Process:**
    1.  The script reads the `templates/discover_candidates.md` file.
    2.  It populates the placeholders (e.g., `{{VENUE_NAME}}`, `{{TIME_WINDOW}}`) in the template using data from `job.json`.
    3.  This populated prompt is sent to the configured LLM provider.
- **Output:** The LLM returns a single, large JSON object matching the `preproduction.json` schema. This file is saved to the run directory (e.g., `runs/<run_id>/preproduction.json`) and governs all subsequent steps.

## 3. Stage 2: Asset Generation
### 3.1. Image Generation
- **Input:** The `candidates` array and `visual_authenticity` data from `preproduction.json`.
- **Process:**
    1.  The script iterates from `i = 0` to `N-1` through the candidates.
    2.  For each candidate `i`, it populates the `templates/gen_image.md` template with the corresponding subject data, scene details, and style profile from `preproduction.json`.
    3.  The completed prompt is sent to the Image Generation API.
    4.  The resulting image is saved as `images/subjects/subject_{i}.png`.

### 3.2. Video Generation
- **Input:** The `N` images generated in the previous step and the `motion_footage` profile from `preproduction.json`.
- **Process:**
    1.  The script iterates from `i = 0` to `N-2`.
    2.  For each `i`, it defines `Image A` as `subject_{i}.png` and `Image B` as `subject_{i+1}.png`.
    3.  It populates the `templates/gen_video.md` template, specifying the start and end images, desired duration, and motion aesthetic.
    4.  The completed prompt is sent to the Video Generation API.
    5.  The resulting video is saved as `videos/clips/transition_{i}_to_{i+1}.mp4`.

## 4. Stage 3: Final Assembly
### 4.1. Stitching & Overlays
- **Process:**
    1.  **Create Static Clips:** The script iterates through the `N` subject images. For each `subject_{i}.png`, it uses `ffmpeg` to create a static video clip of a fixed duration (e.g., 3 seconds).
    2.  **Apply Labels:** During this conversion, `ffmpeg`'s `drawtext` filter adds the subject's name and age as a text overlay onto the static clip.
    3.  **Concatenate:** The script creates a file list (`filelist.txt`) in the correct order:
        - `static_clip_0.mp4`
        - `transition_0_to_1.mp4`
        - `static_clip_1.mp4`
        - `transition_1_to_2.mp4`
        - ...
        - `static_clip_{N-1}.mp4`
    4.  A final `ffmpeg -f concat` command stitches these clips together into `final.mp4`.

## 5. Implementation Skeleton (`run.sh`)
```bash
#!/usr/bin/env bash
set -euo pipefail

# Setup: Read job, create output directories
JOB="${1:-job.json}"
RUN_ID="$(date +%Y%m%d_%H%M%S)"
OUT="runs/${RUN_ID}"
mkdir -p "${OUT}"/{prompts,images/subjects,videos/clips,videos/stills}

# STAGE 1: RESEARCH
# Populate templates/discover_candidates.md from job.json and call LLM
# curl $LLM_PROVIDER ... > "${OUT}/preproduction.json"
echo "Stage 1: Research complete. preproduction.json created."

# STAGE 2: ASSET GENERATION
# 2a: Image Generation
N_SUBJECTS=$(jq '.candidates | length' "${OUT}/preproduction.json")
for i in $(seq 0 $((N_SUBJECTS - 1))); do
  # Populate templates/gen_image.md from preproduction.json for subject $i
  # curl $IMAGE_PROVIDER ... > "${OUT}/images/subjects/subject_${i}.png"
  echo "Generated image for subject ${i}."
done

# 2b: Video Generation (Transitions)
for i in $(seq 0 $((N_SUBJECTS - 2))); do
  IMG_A="${OUT}/images/subjects/subject_${i}.png"
  IMG_B="${OUT}/images/subjects/subject_${i+1}.png"
  # Populate templates/gen_video.md with IMG_A, IMG_B, and motion data
  # curl $VIDEO_PROVIDER ... > "${OUT}/videos/clips/transition_${i}_to_$((i+1)).mp4"
  echo "Generated transition video from subject ${i} to $((i+1))."
done
echo "Stage 2: Asset generation complete."

# STAGE 3: FINAL ASSEMBLY
FILE_LIST="${OUT}/filelist.txt"
> "$FILE_LIST" # Clear file

# 3a: Create static clips with overlays and build file list
STILL_DURATION=3
for i in $(seq 0 $((N_SUBJECTS - 1))); do
  IMG_IN="${OUT}/images/subjects/subject_${i}.png"
  VID_OUT="${OUT}/videos/stills/still_${i}.mp4"
  NAME=$(jq -r ".candidates[${i}].full_name" "${OUT}/preproduction.json")
  AGE=$(jq -r ".candidates[${i}].estimated_age_during_time_window" "${OUT}/preproduction.json")
  
  ffmpeg -loop 1 -i "$IMG_IN" -c:v libx264 -t "$STILL_DURATION" -pix_fmt yuv420p \
    -vf "drawtext=text='${NAME} (${AGE})':x=10:y=h-th-10:fontsize=24:fontcolor=white:box=1:boxcolor=black@0.5" \
    "$VID_OUT"
  
  echo "file '$VID_OUT'" >> "$FILE_LIST"
  # Add the transition video to the list, unless it's the last still
  if [ "$i" -lt $((N_SUBJECTS - 1)) ]; then
    TRANSITION_VID="${OUT}/videos/clips/transition_${i}_to_$((i+1)).mp4"
    echo "file '$TRANSITION_VID'" >> "$FILE_LIST"
  fi
done

# 3b: Concatenate all clips
ffmpeg -f concat -safe 0 -i "$FILE_LIST" -c copy "${OUT}/final.mp4"
echo "Stage 3: Final assembly complete."
echo "DONE: ${OUT}/final.mp4"
```