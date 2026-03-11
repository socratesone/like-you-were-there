#!/usr/bin/env bash
set -euo pipefail

# stitch_and_label.sh <run_dir> <out_final.mp4>
RUN_DIR="$1"
OUT_FINAL="$2"

CLIPS_DIR="${RUN_DIR}/videos/clips"
TMP_LIST="${RUN_DIR}/filelist.txt"

rm -f "${TMP_LIST}"
for f in "${CLIPS_DIR}"/*.mp4; do
  [ -e "$f" ] || continue
  echo "file '$f'" >> "${TMP_LIST}"
done

if [ ! -s "${TMP_LIST}" ]; then
  echo "No clips found to stitch." >&2
  exit 5
fi

# Simple concat
ffmpeg -y -f concat -safe 0 -i "${TMP_LIST}" -c copy "${RUN_DIR}/videos/stitched.mp4"

# Add minimal labels: Show subject name/age when each clip starts. We will overlay a single static title for simplicity.
TITLE="$(jq -r '"\(.venue) — \(.location) — \(.date)"' "${RUN_DIR}/job.json")"

ffmpeg -y -i "${RUN_DIR}/videos/stitched.mp4" -vf "drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:text='${TITLE}':fontcolor=white:fontsize=36:x=20:y=20:box=1:boxcolor=black@0.5" -c:a copy "${OUT_FINAL}"

echo "Wrote ${OUT_FINAL}"
