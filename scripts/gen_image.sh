#!/usr/bin/env bash
set -euo pipefail

# gen_image.sh "<prompt>" <out.png> <index>
PROMPT="$1"
OUT_PATH="$2"
IDX="$3"

mkdir -p "$(dirname "${OUT_PATH}")"

# Providers config
PROVIDERS_FILE="${ROOT_DIR:-$(dirname "$0" )/..}/providers.json"
IMG_ENDPOINT=$(jq -r '.image.endpoint // empty' "${PROVIDERS_FILE}" 2>/dev/null || true)
IMG_KEY_ENV=$(jq -r '.image.api_key_env // empty' "${PROVIDERS_FILE}" 2>/dev/null || true)

if [ -n "${IMG_ENDPOINT}" ] && [ -n "${!IMG_KEY_ENV:-}" ] 2>/dev/null; then
  echo "Calling image endpoint for subject ${IDX} -> ${OUT_PATH}"
  PAYLOAD=$(jq -n --arg prompt "$PROMPT" '{prompt:$prompt, size:"1024x1024"}')
  RESP=$(curl -s -X POST "${IMG_ENDPOINT}" -H "Authorization: Bearer ${!IMG_KEY_ENV}" -H 'Content-Type: application/json' -d "$PAYLOAD")
  # Handle responses that return b64 or url
  B64=$(echo "$RESP" | jq -r '.data[0].b64_json // empty' 2>/dev/null || true)
  URL=$(echo "$RESP" | jq -r '.data[0].url // empty' 2>/dev/null || true)
  if [ -n "$B64" ]; then
    echo "$B64" | base64 -d > "${OUT_PATH}"
    echo "Wrote ${OUT_PATH} (from b64)"
    exit 0
  elif [ -n "$URL" ]; then
    curl -s -o "${OUT_PATH}" "$URL"
    echo "Wrote ${OUT_PATH} (downloaded)"
    exit 0
  else
    echo "Image provider returned no usable data, falling back to local mock." >&2
  fi
fi

echo "Generating synthetic image for subject ${IDX} -> ${OUT_PATH}"

# Use ffmpeg to generate a 1024x1024 PNG with a colored background and label
ffmpeg -y -f lavfi -i color=c=0x323232:s=1024x1024 -vf "drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:text='Subject ${IDX}':fontcolor=white:fontsize=48:x=(w-text_w)/2:y=(h-text_h)/2, drawbox=x=0:y=h-120:w=iw:h=120:color=black@0.6:t=max, drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf:text='${PROMPT}':fontcolor=white:fontsize=18:x=20:y=h-100" -frames:v 1 "${OUT_PATH}" 2>/dev/null || (
  # If drawtext/font not available, create a plain color image
  convert -size 1024x1024 xc:#323232 "${OUT_PATH}" || true
)

echo "Wrote ${OUT_PATH}"
