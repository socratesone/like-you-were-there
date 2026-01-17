#!/usr/bin/env bash
set -euo pipefail

JOB_PATH="$1"
OUT_PATH="${2:-candidates.raw.json}"

LOCATION=$(jq -r .location "${JOB_PATH}")
DATE=$(jq -r .date "${JOB_PATH}")

echo "{\"meta\": {\"location\": \"${LOCATION}\", \"date\": \"${DATE}\"}, \"candidates\": []}" > "${OUT_PATH}"

cat <<'NOTE' >&2
discover_candidates.sh: By default this writes an empty candidate list placeholder.
To enable real discovery, replace this script's body with a SPARQL query against
Wikidata's Query Service (https://query.wikidata.org/sparql) and save the JSON.
Example (curl):
curl -G 'https://query.wikidata.org/sparql' --data-urlencode "query=SELECT ?person ?personLabel WHERE { ... } LIMIT 50" -H 'Accept: application/sparql-results+json' > candidates.raw.json
NOTE

echo "Wrote placeholder candidates to ${OUT_PATH}"
