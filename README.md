# Like You Were There

Generate a short, stylized “walkthrough” video that *feels like you were present* at a specific place and time.

This repository is a runnable scaffold for a **Time‑Place Walkthrough Generator** pipeline: given a `job.json` describing a venue/location/date and a desired aesthetic, it produces a stitched MP4 made from AI-generated stills and transition clips.

## What it does

- Takes a simple JSON config (`job.json`) describing **place + date + style**.
- Produces a run folder under `runs/<run_id>/` containing:
	- `job.json` (resolved inputs)
	- `subjects.json` (the subject list and prompts)
	- generated images and per-subject clips
	- a stitched video `videos/final.mp4`
	- logs and a lightweight `report.md`

## Status / scope

This is intentionally a scaffold:

- The current runnable entrypoint is `run.sh`, which uses prompt templates in `templates/`.
- The `specs/` folder describes a more complete, template-driven design and data schemas.
- The `scripts/` folder contains an earlier/alternate shell-first scaffold (some pieces are placeholders).

This project is best treated as an experimentation harness: the goal is a repeatable run folder with prompts, intermediate artifacts, and a final stitched video.

## Quick start

Prereqs:

- bash
- jq
- curl
- python3
- ffmpeg

API keys:

- `OPENAI_API_KEY` (research + images)
- `REPLICATE_API_TOKEN` (transition videos)

Run the example:

```bash
chmod +x run.sh scripts/*.sh
./run.sh example_job.json
```

The default `example_job.json` is safe to run without API keys (it uses local mocks). For a real-provider example, see `job.example.json`.

After it finishes, look in the newest run folder:

```bash
ls -1 runs | tail
```

The final output video is written to:

```
runs/<run_id>/videos/final.mp4
```

## Configuration (job.json)

The job file is the primary input. See `example_job.json` for a complete minimal configuration.

Common fields:

- `location`: e.g., `"New York City, NY, USA"`
- `venue`: e.g., `"CBGB"`
- `date`: `YYYY-MM-DD`
- `num_subjects`: how many subjects to feature
- `output_seconds`: target duration (currently advisory)
- `era_style`, `camera_style`: freeform aesthetic guidance

Provider hints (used as model IDs):

- `provider.llm` (example: `openai/gpt-4-turbo`)
- `provider.image_gen` (example: `openai/dall-e-3`)
- `provider.video_gen` (example: `replicate/google/veo-3.1-fast`)

Note: `run.sh` currently derives the OpenAI model name by taking the part after `/`.

Safety flags (default to `false` if omitted):

- `allow_living_people`
- `allow_minors`

If `allow_living_people` is `true`, the run requires an `ATTESTATION` environment variable to be set (see “Safety”).

## API configuration

The simplest way to configure keys is to export them:

```bash
export OPENAI_API_KEY="..."
export REPLICATE_API_TOKEN="..."
./run.sh example_job.json
```

`run.sh` also loads a local `.env` file if present.

Recommended setup:

- Copy `.env.example` → `.env` and fill in your keys.
- Copy `job.example.json` → `job.json` and tweak inputs.

Note: `.env`, `job.json`, and `runs/` are intentionally ignored by git.

## Outputs

Each run creates a folder:

```
runs/<run_id>/
	job.json
	preproduction.json
	prompts/
	logs/
	images/
	videos/clips/
	videos/stills/
	videos/final.mp4
	report.md
```

If you’re debugging a run, start with `logs/run.log` and then the per-step logs in `logs/`.

## Safety & responsible use

This project is intended for **plausible, artistic dramatizations** (not photorealistic impersonation).

Default guardrails (recommended):

- `allow_living_people=false`
- `allow_minors=false`

If you explicitly enable living people (`allow_living_people=true`), you must set:

```bash
export ATTESTATION="I have the rights/consent to use depicted living persons."
```

See `specs/safety.md` for the full safety/compliance rationale and logging expectations.

## How the pipeline works (today)

At a high level, `run.sh` orchestrates:

1. **Research / preproduction** (OpenAI chat completions) using `templates/discover_candidates.md` → `preproduction.json`
2. **Subject still images** (OpenAI Images API) using `templates/gen_image.md` → `images/subject_<i>.png`
3. **Transition clips** (Replicate) between stills → `videos/clips/transition_<i>_to_<j>.mp4`
4. **Final assembly** (ffmpeg) stills + transitions → `videos/final.mp4`

Prompts and raw API responses are saved under `prompts/` and `logs/` for debugging.

## Troubleshooting

- **"Missing job.json"**: pass a path, e.g. `./run.sh path/to/job.json`.
- **Script exits with curl code 6 during image generation**: usually means the Images API returned no URL/b64, and the script tried to download `null`. Check `runs/<run_id>/logs/image_<i>_openai_response.json` for the actual error.
- **Fonts/drawtext issues in mocks**: the local image/video mocks use `ffmpeg` + DejaVu fonts. Install `fonts-dejavu` (package name varies by distro) if drawtext fails.
- **Replicate job fails**: inspect the poll response printed to the console; verify your `REPLICATE_API_TOKEN` and the model version ID.

## Contributing

This repo is intentionally shell-first and easy to hack on. Good next contributions:

- Enforce safety guardrails programmatically (not just in the prompt).
- Replace the temporary image hosting (`tmp.ninja`) with a more robust approach.
- Make the Replicate model selection/version configurable (and/or add a local video mock).

## License

No license is specified in this repository. If you plan to use or redistribute it, add a license file.
