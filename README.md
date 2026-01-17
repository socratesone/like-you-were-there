# Time-Place Celebrity Walkthrough Generator (TPCWG)

This repo contains a runnable scaffold for the TPCWG pipeline. It defaults to calling OpenAI for LLM and image generation (alpha) but remains configurable via `providers.json`.

Prereqs:
- bash, jq, ffmpeg, python3, curl

Quick run (uses `example_job.json`):

```bash
chmod +x run.sh scripts/*.sh
./run.sh example_job.json
```

Outputs are created under `runs/<run_id>/` and include `final.mp4`, `subjects.json`, and `report.md`.

Configuring providers:
- Edit `providers.json` to set `endpoint` and `api_key_env` for `llm`, `image`, and `video`.
- By default `llm` and `image` point to OpenAI endpoints and expect the `OPENAI_API_KEY` env var. `video` is left as `mock` by default.
- You can also override endpoints per-job by adding provider details into `job.json` under `provider`.

Notes:
- The scripts in `scripts/` will attempt to call configured provider endpoints and fall back to local ffmpeg-based mocks when providers are not configured or return no usable data.
- Safety guardrails: `allow_living_people=false` and `allow_minors=false` by default; if `allow_living_people` is enabled the run requires an `ATTESTATION` env var to be set.
# like-you-were-there
