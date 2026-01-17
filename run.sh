#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JOB_PATH="${1:-job.json}"

if [ ! -f "${JOB_PATH}" ]; then
  echo "Missing job.json. Provide a path or place job.json in the repo root." >&2
  exit 2
fi

RUN_ID="$(date +%Y%m%d_%H%M%S)"
OUT="${ROOT_DIR}/runs/${RUN_ID}"
mkdir -p "${OUT}/"{prompts,images/subjects,videos/clips,logs}
cp "${JOB_PATH}" "${OUT}/job.json"

echo "Run: ${RUN_ID}" | tee "${OUT}/logs/run.log"

# Load job basics
LOCATION=$(jq -r .location "${JOB_PATH}")
DATE=$(jq -r .date "${JOB_PATH}")
NUM_SUBJECTS=$(jq -r .num_subjects "${JOB_PATH}")

# Safety defaults
ALLOW_LIVING=$(jq -r '.allow_living_people // false' "${JOB_PATH}")
ALLOW_MINORS=$(jq -r '.allow_minors // false' "${JOB_PATH}")

if [ "${ALLOW_LIVING}" = "true" ] && [ -z "${ATTESTATION:-}" ]; then
  echo "allow_living_people is true but ATTESTATION env var is not set. Set ATTESTATION to confirm rights." >&2
  exit 3
fi

echo "Discovering candidates for ${LOCATION} @ ${DATE}..." | tee -a "${OUT}/logs/run.log"
"${ROOT_DIR}/scripts/discover_candidates.sh" "${JOB_PATH}" "${OUT}/candidates.raw.json" | tee -a "${OUT}/logs/discover.log"

echo "Refining subjects with LLM (or local mock)..." | tee -a "${OUT}/logs/run.log"
"${ROOT_DIR}/scripts/refine_subjects.sh" "${OUT}/candidates.raw.json" "${JOB_PATH}" "${OUT}/subjects.json" | tee -a "${OUT}/logs/refine.log"

NUM_FOUND=$(jq -r '.subjects | length' "${OUT}/subjects.json")
if [ "${NUM_FOUND}" -lt 1 ]; then
  echo "No subjects found." >&2
  exit 4
fi

echo "Generating images and videos for ${NUM_FOUND} subjects..." | tee -a "${OUT}/logs/run.log"
for (( idx=0; idx<NUM_FOUND; idx++ )); do
  i=$((idx+1))
  name=$(jq -r ".subjects[${idx}].name" "${OUT}/subjects.json")
  prompt_image=$(jq -r ".subjects[${idx}].prompt_image" "${OUT}/subjects.json")
  prompt_video=$(jq -r ".subjects[${idx}].prompt_video" "${OUT}/subjects.json")

  echo "Subject ${i}: ${name}" | tee -a "${OUT}/logs/run.log"
  IMG_OUT="${OUT}/images/subjects/${i}.png"
  VID_OUT="${OUT}/videos/clips/${i}.mp4"

  "${ROOT_DIR}/scripts/gen_image.sh" "${prompt_image}" "${IMG_OUT}" "${i}" | tee -a "${OUT}/logs/image_${i}.log"
  "${ROOT_DIR}/scripts/gen_video.sh" "${prompt_video}" "${IMG_OUT}" "${VID_OUT}" "${i}" | tee -a "${OUT}/logs/video_${i}.log"
done

echo "Stitching clips and adding labels..." | tee -a "${OUT}/logs/run.log"
"${ROOT_DIR}/scripts/stitch_and_label.sh" "${OUT}" "${OUT}/videos/final.mp4" | tee -a "${OUT}/logs/stitch.log"

echo "Generating report..." | tee -a "${OUT}/logs/run.log"
python3 - <<PY
import json,sys,os,datetime
out='''# Report
Run ID: %s
Date: %s

Files:
 - job.json: %s
 - subjects.json: %s
 - final video: %s
''' % ("%s" % os.path.basename("${OUT}"), datetime.datetime.now(), "${OUT}/job.json", "${OUT}/subjects.json", "${OUT}/videos/final.mp4")
open("${OUT}/report.md","w").write(out)
print('Wrote report to ${OUT}/report.md')
PY

echo "DONE: ${OUT}/videos/final.mp4"
