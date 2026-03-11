#!/usr/bin/env bash
set -euo pipefail

# refine_subjects.sh <candidates.json> <job.json> <out_subjects.json>
CANDIDATES_PATH="${1:-/dev/null}"
JOB_PATH="${2:-job.json}"
OUT_PATH="${3:-subjects.json}"

NUM_SUBJECTS=$(jq -r .num_subjects "${JOB_PATH}")

if [ -n "${LLM_ENDPOINT}" ] && [ -n "${!LLM_KEY_ENV:-}" ]; then

# If providers.json or job overrides point to an LLM, use it. Otherwise fallback to synthetic.
LLM_ENDPOINT=$(jq -r '.llm.endpoint // empty' "${PROVIDERS_FILE}" 2>/dev/null || true)
LLM_KEY_ENV=$(jq -r '.llm.api_key_env // empty' "${PROVIDERS_FILE}" 2>/dev/null || true)

if [ -n "${LLM_ENDPOINT}" ] && [ -n "${!LLM_KEY_ENV:-}" ] 2>/dev/null; then
  # Build a simple prompt for the LLM with the candidate list and job info
  CAND_JSON=$(jq -c '.' "${CANDIDATES_PATH}" 2>/dev/null || echo '{}')
{ "subjects": [ { "name": string, "birth_date": string|null, "age": integer|null, "evidence": [string], "plausibility_note": string, "prompt_image": string, "prompt_video": string } ] }

  PAYLOAD=$(jq -n --arg candidates "$CAND_JSON" --arg job "$JOB_JSON" --arg num "${NUM_SUBJECTS}" '{model: ($job | fromjson? | .provider.llm) // "gpt-4o-mini", messages: [{role:"system", content:"You are an assistant that extracts a list of plausible historical subjects and outputs strict JSON matching the subjects.json schema."},{role:"user", content: "Candidates: " + $candidates + "\nJob: " + $job + "\nReturn exactly JSON with key \"subjects\" and array of desired length (" + $num + ")."}]}' )

  # Call LLM
  RESP=$(curl -s -X POST "${LLM_ENDPOINT}" \
    -H "Authorization: Bearer ${!LLM_KEY_ENV}" \
    -H 'Content-Type: application/json' \
    -d "$PAYLOAD")

  # Try to extract assistant content
  CONTENT=$(echo "$RESP" | jq -r '.choices[0].message.content // empty' 2>/dev/null || true)
  if [ -n "$CONTENT" ]; then
    # Validate JSON — try to parse; if valid, write out
    echo "$CONTENT" | jq '.' > "${OUT_PATH}" 2>/dev/null || true
    if [ -s "${OUT_PATH}" ]; then
      echo "Wrote ${OUT_PATH} from LLM" && exit 0
    fi
  fi
fi

# Fallback: create simple synthetic subjects (same as before)
jq -n --argjson n ${NUM_SUBJECTS} '
  {subjects: [range(0;$n) | {name: ("Subject " + (.|tostring)), birth_date: null, age: null, evidence: ["generated"], plausibility_note: "Synthetic subject for local run", prompt_image: "A stylized portrait of a person in a crowd.", prompt_video: "A short handheld walkthrough focusing on the person."}]}
' > "${OUT_PATH}"

echo "Wrote synthetic ${OUT_PATH}"
