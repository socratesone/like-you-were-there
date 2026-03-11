# Product Requirements Document (PRD)
## Time-Place Celebrity Walkthrough Generator (TPCWG)

## 1. Overview
The TPCWG is a tool that generates an AI "walkthrough" video of a real-world venue at a specified time. The video gives the impression of moving through a crowd and periodically focusing on notable people plausibly associated with that place and time.

The goal is to create a simple, automatable pipeline using LLMs, image generation, and video generation to produce a single, stylized MP4 video.

## 2. Core Product Goals
- **Input:** Accept a simple configuration (`job.json`) specifying a place, venue, date, and desired aesthetic.
- **Output:** Produce a single MP4 video that simulates a camera moving through the specified scene.
- **Key Feature: Subject Focus:** The video will repeatedly pause to focus on a plausible historical figure, displaying their name and age at the time.
- **Aesthetic Consistency:** The final video must maintain a consistent, period-appropriate look and feel, from camera style to wardrobe.

## 3. Non-Goals
- **Perfect Historical Accuracy:** The tool generates a *plausible* scene, not a documentary.
- **Consistent Identity:** Individual subjects are not expected to have perfect visual consistency across multiple shots or long clips.
- **Photorealistic Deepfakes:** The output is an artistic dramatization, not a tool for impersonation.

## 4. User Configuration (`job.json`)
The user must provide a `job.json` file with the following required inputs:
- `location`: e.g., "New York City, NY, USA"
- `venue`: e.g., "CBGB"
- `date`: e.g., "1977-08-15"
- `num_subjects`: The number of notable people to feature.
- `output_seconds`: The total desired length of the video.
- `era_style`: A short description of the scene's aesthetic (e.g., "late-70s downtown punk club").
- `camera_style`: A short description of the camera feel (e.g., "handheld, 16mm, grain").
- `provider`: API selections for LLM, image, and video generation.

## 5. Deliverables (Output Artifacts)
Each run will generate a directory (`runs/<run_id>/`) containing:
- The final video: `final.mp4`
- The configuration file used: `job.json`
- The list of subjects featured: `subjects.json`
- All prompts used for generation: `prompts/`
- Intermediate images and video clips.
- A final report with costs and timings.

## 6. On-Screen Information (Labels)
The final video will include text overlays to provide context:
- **Title Card (Optional):** "{Venue} — {Location} — {Date}" at the beginning.
- **Subject Labels:** "{Name} — {Age}" displayed when a subject is on screen.
