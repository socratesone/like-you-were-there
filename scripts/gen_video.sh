#!/usr/bin/env bash
set -euo pipefail

# gen_video.sh "<prompt>" <image.png> <out.mp4> <index>
PROMPT="$1"
IMAGE="$2"
OUT_PATH="$3"
IDX="$4"

mkdir -p "$(dirname "${OUT_PATH}")"

# Providers config
PROVIDERS_FILE="${ROOT_DIR:-$(dirname "$0" )/..}/providers.json"
VID_ENDPOINT=$(jq -r '.video.endpoint // empty' "${PROVIDERS_FILE}" 2>/dev/null || true)
VID_KEY_ENV=$(jq -r '.video.api_key_env // empty' "${PROVIDERS_FILE}" 2>/dev/null || true)

if [ -n "${VID_ENDPOINT}" ] && [ -n "${!VID_KEY_ENV:-}" ] 2>/dev/null; then
  echo "Calling video endpoint for subject ${IDX} -> ${OUT_PATH}"
  PAYLOAD=$(jq -n --arg prompt "$PROMPT" --arg image_path "$IMAGE" '{prompt:$prompt}')
  RESP=$(curl -s -X POST "${VID_ENDPOINT}" -H "Authorization: Bearer ${!VID_KEY_ENV}" -H 'Content-Type: application/json' -d "$PAYLOAD")
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
    echo "Video provider returned no usable data, falling back to local mock." >&2
  fi
fi

echo "Generating synthetic video for subject ${IDX} -> ${OUT_PATH}"

# Create a short 4s clip by panning/zooming the subject image (image-to-video mock)
ffmpeg -y -loop 1 -i "${IMAGE}" -vf "zoompan=z='if(lte(pzoom,1.0),1.0,zoom+0.001)':d=125,format=yuv420p" -t 4 -r 25 "${OUT_PATH}" 2>/dev/null || (
  # fallback: generate solid color video
  ffmpeg -y -f lavfi -i color=c=0x111111:s=1280x720:d=4 -vf "drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf:text='Subject ${IDX}':fontcolor=white:fontsize=48:x=(w-text_w)/2:y=(h-text_h)/2" -c:v libx264 -t 4 -pix_fmt yuv420p "${OUT_PATH}"
)

echo "Wrote ${OUT_PATH}"
