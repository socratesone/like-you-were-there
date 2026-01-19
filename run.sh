#!/usr/bin/env bash
set -euo pipefail

# --- Configuration & Setup ---
JOB_FILE="${1:-job.json}"
if [ ! -f "$JOB_FILE" ]; then
    echo "Error: Job file '$JOB_FILE' not found."
    exit 1
fi

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    # Use 'export' to ensure variables are available in the script's environment
    export $(grep -v '^#' .env | xargs)
fi

# Check for required API keys
if [ -z "${OPENAI_API_KEY:-}" ] || [ -z "${REPLICATE_API_TOKEN:-}" ]; then
    echo "Error: OPENAI_API_KEY and REPLICATE_API_TOKEN must be set in your .env file."
    exit 1
fi

RUN_ID="$(date +%Y%m%d_%H%M%S)"
OUT_DIR="runs/${RUN_ID}"
mkdir -p "${OUT_DIR}"/{prompts,images,videos/clips,videos/stills,logs}
cp "${JOB_FILE}" "${OUT_DIR}/job.json"
echo "Run started. All artifacts will be saved in ${OUT_DIR}"

replicate_upload_file() {
  local file_path="$1"
  local label="$2"
  local resp
  local resp_file
  local url

  resp_file="${OUT_DIR}/logs/${label}_replicate_file_upload.json"
  resp=$(curl -sS -X POST "https://api.replicate.com/v1/files" \
    -H "Authorization: Token $REPLICATE_API_TOKEN" \
    -F "content=@${file_path}")
  echo "$resp" > "$resp_file"

  # Replicate has returned different shapes over time; try a few likely fields.
  url=$(echo "$resp" | jq -r '.urls.get // .urls.download // .url // .get // empty' 2>/dev/null || true)
  if [ -z "$url" ] || [ "$url" = "null" ]; then
    echo "Error: Replicate file upload did not return a usable URL." >&2
    echo "Response saved to: ${resp_file}" >&2
    echo "$resp" | jq -r '.detail // .error // .message // "(no error field)"' >&2 || true
    return 1
  fi

  echo "$url"
}

# --- STAGE 1: RESEARCH (LLM) ---
echo "--- Stage 1: Research ---"
PROMPT_TEMPLATE="templates/discover_candidates.md"
RESEARCH_PROMPT_FILE="${OUT_DIR}/prompts/00_research_prompt.txt"

# Populate the research prompt template
sed "s/{{PLACE_NAME}}/$(jq -r .venue ${JOB_FILE})/g; \
     s/{{PLACE_CITY}}/$(jq -r .location ${JOB_FILE})/g; \
     s/{{VENUE_NAME}}/$(jq -r .venue ${JOB_FILE})/g; \
     s/{{TIME_WINDOW}}/$(jq -r .date ${JOB_FILE})/g; \
     s/{{NOTES}}/$(jq -r .era_style ${JOB_FILE})/g; \
     s/{{TARGET_SUBJECT_COUNT}}/$(jq -r .num_subjects ${JOB_FILE})/g; \
     s/{{ALLOW_LIVING_PEOPLE}}/$(jq -r .allow_living_people ${JOB_FILE})/g; \
     s/{{ALLOW_MINORS}}/$(jq -r .allow_minors ${JOB_FILE})/g" \
     "${PROMPT_TEMPLATE}" > "${RESEARCH_PROMPT_FILE}"

echo "Populated research prompt. Calling OpenAI LLM..."
PREPROD_FILE="${OUT_DIR}/preproduction.json"

# Read the prompt content into a shell variable
PROMPT_CONTENT=$(cat "$RESEARCH_PROMPT_FILE")

# Use jq to build the JSON payload. This is a more robust method
# than using a heredoc with command substitution.
JSON_PAYLOAD=$(jq -n \
  --arg model "$(jq -r '.provider.llm' "$JOB_FILE" | cut -d'/' -f2)" \
  --arg prompt_content "$PROMPT_CONTENT" \
  '{
    "model": $model,
    "response_format": { "type": "json_object" },
    "messages": [
      {
        "role": "system",
        "content": "You are an expert historical researcher and visual-reference researcher for film/photography authenticity. You produce strictly structured outputs that follow the provided JSON schema."
      },
      {
        "role": "user",
        "content": $prompt_content
      }
    ]
  }')

# This command calls the OpenAI Chat API to run the research stage.
LLM_RESPONSE=$(curl -s https://api.openai.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d "$JSON_PAYLOAD"
)

LLM_RAW_RESPONSE_FILE="${OUT_DIR}/prompts/01_llm_raw_response.json"

echo "$LLM_RESPONSE" > "$LLM_RAW_RESPONSE_FILE"

LLM_CONTENT=$(echo "$LLM_RESPONSE" | jq -r '.choices[0].message.content')

if [ "$LLM_CONTENT" == "null" ] || [ -z "$LLM_CONTENT" ]; then
    echo "Error: LLM did not return valid content. The raw API response was:"
    cat "$LLM_RAW_RESPONSE_FILE"
    exit 1
fi

echo "$LLM_CONTENT" > "$PREPROD_FILE"
echo "Research complete. 'preproduction.json' created."

# --- STAGE 2: ASSET GENERATION ---
echo "--- Stage 2: Asset Generation ---"
N_SUBJECTS=$(jq '.candidates | length' "${PREPROD_FILE}")
IMAGE_URLS=()

# 2a: Image Generation (DALL-E 3)
echo "--- 2a: Generating subject images ---"
for i in $(seq 0 $((N_SUBJECTS - 1))); do
    IMG_PROMPT_FILE="${OUT_DIR}/prompts/image_${i}.txt"
    CANDIDATE_JSON=$(jq ".candidates[${i}]" "$PREPROD_FILE")
    VISUAL_JSON=$(jq ".visual_authenticity" "$PREPROD_FILE")

    # Extract values into shell variables first
    VENUE_NAME=$(jq -r .place_time.venue_name "${PREPROD_FILE}")
    PLACE_CITY=$(jq -r .location "${JOB_FILE}")
    TIME_WINDOW=$(jq -r .date "${JOB_FILE}")
    PERSON_FULL_NAME=$(echo "$CANDIDATE_JSON" | jq -r .full_name)
    PERSON_AGE=$(echo "$CANDIDATE_JSON" | jq -r .estimated_age_during_time_window)
    STILL_LOOK_PROFILE=$(echo "$VISUAL_JSON" | jq -c .still_photography)

    # OpenAI Images often rejects prompts that try to depict real people by name.
    # Default behavior: redact names in the image prompt, but keep the real name in preproduction.json for labeling.
    PERSON_FOR_IMAGE_PROMPT="$PERSON_FULL_NAME"
    if [ "${ALLOW_REAL_PERSON_NAMES_IN_IMAGE_PROMPTS:-false}" != "true" ]; then
      PERSON_FOR_IMAGE_PROMPT="a plausible late-1970s punk scene regular (fictional)"
    fi

    # Now use these variables in sed
        sed "s~{{VENUE_NAME}}~${VENUE_NAME}~g; \
          s~{{PLACE_CITY}}~${PLACE_CITY}~g; \
          s~{{TIME_WINDOW}}~${TIME_WINDOW}~g; \
          s~{{PERSON_FULL_NAME}}~${PERSON_FOR_IMAGE_PROMPT}~g; \
          s~{{PERSON_AGE}}~${PERSON_AGE}~g; \
          s~{{STILL_LOOK_PROFILE}}~${STILL_LOOK_PROFILE}~g" \
         "templates/gen_image.md" > "$IMG_PROMPT_FILE"

    if [ "${ALLOW_REAL_PERSON_NAMES_IN_IMAGE_PROMPTS:-false}" = "true" ]; then
      echo "Generating image ${i} for ${PERSON_FULL_NAME} (using real name in prompt)..."
    else
      echo "Generating image ${i} for ${PERSON_FULL_NAME} (prompt subject redacted)..."
    fi
    
    # This command calls the OpenAI Images API to generate a still image for a subject.
    IMAGE_MODEL="$(jq -r '.provider.image_gen' "$JOB_FILE" | cut -d'/' -f2)"
    IMG_PROMPT_CONTENT="$(cat "$IMG_PROMPT_FILE")"
    IMG_PAYLOAD=$(jq -n \
      --arg model "$IMAGE_MODEL" \
      --arg prompt "$IMG_PROMPT_CONTENT" \
      '{model:$model, prompt:$prompt, n:1, size:"1024x1024"}')

    IMG_RESPONSE=$(curl -sS https://api.openai.com/v1/images/generations \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $OPENAI_API_KEY" \
      -d "$IMG_PAYLOAD" \
    )

    IMG_RAW_RESPONSE_FILE="${OUT_DIR}/logs/image_${i}_openai_response.json"
    echo "$IMG_RESPONSE" > "$IMG_RAW_RESPONSE_FILE"

    IMG_PATH="${OUT_DIR}/images/subject_${i}.png"
    IMG_URL=$(echo "$IMG_RESPONSE" | jq -r '.data[0].url // empty')
    IMG_B64=$(echo "$IMG_RESPONSE" | jq -r '.data[0].b64_json // empty')

    if [ -n "$IMG_B64" ]; then
        echo "$IMG_B64" | base64 -d > "$IMG_PATH"
        echo "Image ${i} saved to ${IMG_PATH} (b64)"
    elif [ -n "$IMG_URL" ]; then
        curl -sS -L "$IMG_URL" -o "$IMG_PATH"
        echo "Image ${i} saved to ${IMG_PATH} (url)"
    else
      echo "Warning: OpenAI Images API returned no image data for subject ${i}. Falling back to a local mock image." >&2
      echo "Response saved to: ${IMG_RAW_RESPONSE_FILE}" >&2
      echo "Error details (if present):" >&2
      echo "$IMG_RESPONSE" | jq -r '.error.message // .error // "(no error field)"' >&2 || true

      ffmpeg -y -f lavfi -i color=c=0x323232:s=1024x1024 \
        -vf "drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:text='Subject ${i}':fontcolor=white:fontsize=48:x=(w-text_w)/2:y=(h-text_h)/2" \
        -frames:v 1 "${IMG_PATH}" -loglevel error
      IMG_URL=""
      echo "Mock image ${i} saved to ${IMG_PATH}"
    fi
    
    # Get a public URL for the video step.
    # Prefer OpenAI's returned URL when available; otherwise upload to Replicate.
    if [ -n "$IMG_URL" ]; then
      PUBLIC_URL="$IMG_URL"
      echo "Using OpenAI image URL for video step."
    else
      echo "Uploading image ${i} to Replicate for video step..."
      PUBLIC_URL=$(replicate_upload_file "${IMG_PATH}" "image_${i}")
      echo "Replicate file URL for image ${i}: ${PUBLIC_URL}"
    fi

    IMAGE_URLS+=("$PUBLIC_URL")
    echo "Public URL for image ${i}: ${PUBLIC_URL}"
done

# 2b: Video Generation (Replicate)
echo "--- 2b: Generating transition videos ---"
VIDEO_PROVIDER_HINT=$(jq -r '.provider.video_gen // empty' "${JOB_FILE}")

# Determine Replicate model owner/name from job.json (expected: replicate/<owner>/<model>). Allow overrides via env.
REPLICATE_MODEL_VERSION="${REPLICATE_MODEL_VERSION:-}"

if [ -z "${REPLICATE_MODEL_VERSION}" ]; then
  if [[ "${VIDEO_PROVIDER_HINT}" == replicate/*/* ]]; then
    REPLICATE_OWNER=$(echo "${VIDEO_PROVIDER_HINT}" | cut -d'/' -f2)
    REPLICATE_MODEL=$(echo "${VIDEO_PROVIDER_HINT}" | cut -d'/' -f3)
  else
    # Fallback default (kept for convenience)
    REPLICATE_OWNER="google"
    REPLICATE_MODEL="veo-3.1-fast"
  fi

  echo "Resolving Replicate model version for ${REPLICATE_OWNER}/${REPLICATE_MODEL}..."
  MODEL_INFO=$(curl -sS -H "Authorization: Token $REPLICATE_API_TOKEN" \
    "https://api.replicate.com/v1/models/${REPLICATE_OWNER}/${REPLICATE_MODEL}")
  echo "$MODEL_INFO" > "${OUT_DIR}/logs/replicate_model_info.json"

  REPLICATE_MODEL_VERSION=$(echo "$MODEL_INFO" | jq -r '.latest_version.id // empty')
  if [ -z "${REPLICATE_MODEL_VERSION}" ] || [ "${REPLICATE_MODEL_VERSION}" = "null" ]; then
    echo "Error: Could not resolve a Replicate model version for ${REPLICATE_OWNER}/${REPLICATE_MODEL}." >&2
    echo "Response saved to: ${OUT_DIR}/logs/replicate_model_info.json" >&2
    echo "$MODEL_INFO" | jq -r '.detail // .error // .message // "(no error field)"' >&2 || true
    exit 1
  fi
fi

echo "Using Replicate model version: ${REPLICATE_MODEL_VERSION}"

for i in $(seq 0 $((N_SUBJECTS - 2))); do
    j=$((i + 1))
    echo "Generating transition video from subject ${i} to ${j}..."
    
    START_IMG_URL=${IMAGE_URLS[$i]}
    END_IMG_URL=${IMAGE_URLS[$j]}

    REPLICATE_PROMPT="Transition video, $(jq -r .era_style "${JOB_FILE}")"
    REPLICATE_PAYLOAD=$(jq -n \
      --arg version "${REPLICATE_MODEL_VERSION}" \
      --arg image "${START_IMG_URL}" \
      --arg last_frame "${END_IMG_URL}" \
      --arg prompt "${REPLICATE_PROMPT}" \
      '{version:$version, input:{image:$image, last_frame:$last_frame, prompt:$prompt, resolution:"720p"}}')

    # This command starts a video generation job on Replicate.
    REPLICATE_RESPONSE=$(curl -sS -X POST "https://api.replicate.com/v1/predictions" \
        -H "Authorization: Token $REPLICATE_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "${REPLICATE_PAYLOAD}")

    echo "$REPLICATE_RESPONSE" > "${OUT_DIR}/logs/replicate_start_${i}_to_${j}.json"

    POLL_URL=$(echo "$REPLICATE_RESPONSE" | jq -r '.urls.get')
    if [ -z "$POLL_URL" ] || [ "$POLL_URL" == "null" ]; then
        echo "Error: Failed to start Replicate job. Response:"
        echo "$REPLICATE_RESPONSE"
        exit 1
    fi
    
    # Poll for result
    echo "Replicate job started. Polling for result at ${POLL_URL}..."
    while true; do
      POLL_RESPONSE=$(curl -sS -H "Authorization: Token $REPLICATE_API_TOKEN" "$POLL_URL")
      echo "$POLL_RESPONSE" > "${OUT_DIR}/logs/replicate_poll_${i}_to_${j}.json"
        STATUS=$(echo "$POLL_RESPONSE" | jq -r '.status')
        
        if [ "$STATUS" == "succeeded" ]; then
            VIDEO_URL=$(echo "$POLL_RESPONSE" | jq -r '.output')
            VIDEO_PATH="${OUT_DIR}/videos/clips/transition_${i}_to_${j}.mp4"
            curl -s -L "$VIDEO_URL" -o "$VIDEO_PATH"
            echo "Transition video ${i} -> ${j} downloaded to ${VIDEO_PATH}"
            break
        elif [ "$STATUS" == "failed" ] || [ "$STATUS" == "canceled" ]; then
            echo "Error: Replicate job failed or was canceled."
            echo "$POLL_RESPONSE"
            exit 1
        fi
        sleep 5
    done
done

# --- STAGE 3: FINAL ASSEMBLY ---
echo "--- Stage 3: Final Assembly ---"

# ffmpeg's concat demuxer resolves relative paths relative to the filelist location.
# So we write paths relative to ${OUT_DIR} to avoid duplicate runs/<id>/runs/<id>/... issues.
FILE_LIST="${OUT_DIR}/filelist.txt"
> "$FILE_LIST"

INCLUDE_STILLS="${INCLUDE_STILLS:-false}"

if [ "$INCLUDE_STILLS" = "true" ]; then
  # Optional: create static clips with overlays (useful if you want time on each subject).
  STILL_DURATION="${STILL_DURATION:-4}"
  for i in $(seq 0 $((N_SUBJECTS - 1))); do
    IMG_IN="${OUT_DIR}/images/subject_${i}.png"
    VID_OUT="${OUT_DIR}/videos/stills/still_${i}.mp4"
    NAME=$(jq -r ".candidates[${i}].full_name" "${PREPROD_FILE}")
    AGE=$(jq -r ".candidates[${i}].estimated_age_during_time_window" "${PREPROD_FILE}")

    ffmpeg -loglevel error -loop 1 -i "$IMG_IN" -c:v libx264 -t "$STILL_DURATION" -pix_fmt yuv420p \
      -vf "scale=1280:720,drawtext=text='${NAME} (${AGE})':x=20:y=h-th-20:fontsize=32:fontcolor=white:box=1:boxcolor=black@0.6" \
      "$VID_OUT"

    # Relative paths (relative to ${OUT_DIR})
    echo "file 'videos/stills/still_${i}.mp4'" >> "$FILE_LIST"
    if [ "$i" -lt $((N_SUBJECTS - 1)) ]; then
      echo "file 'videos/clips/transition_${i}_to_$((i + 1)).mp4'" >> "$FILE_LIST"
    fi
  done
else
  # Default: stitch the generated transition clips directly.
  for i in $(seq 0 $((N_SUBJECTS - 2))); do
    echo "file 'videos/clips/transition_${i}_to_$((i + 1)).mp4'" >> "$FILE_LIST"
  done
fi

if [ ! -s "$FILE_LIST" ]; then
  echo "Error: No clips listed for stitching (empty ${FILE_LIST})." >&2
  exit 1
fi

echo "Stitching final video..."
ffmpeg -loglevel error -f concat -safe 0 -i "$FILE_LIST" -c copy "${OUT_DIR}/videos/final.mp4"

echo "--- Run Complete ---"
echo "Final video available at: ${OUT_DIR}/videos/final.mp4"