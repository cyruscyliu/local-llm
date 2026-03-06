#!/usr/bin/env bash
# test_api_key.sh -- Validate an API key against the /v1/models endpoint.
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: tests/test_api_key.sh [--api-key KEY] [--base-url URL] [--model MODEL] [--timeout SECONDS]

Checks that the API key can list models at /v1/models. If --model is provided,
verifies that model appears in the response.

Defaults:
  --api-key   $OPENAI_API_KEY
  --base-url  http://localhost:4000/v1
  --timeout   10
USAGE
}

API_KEY="${OPENAI_API_KEY:-}"
BASE_URL="http://localhost:4000/v1"
MODEL=""
TIMEOUT="10"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -k|--api-key)
      API_KEY="$2"; shift 2 ;;
    -b|--base-url)
      BASE_URL="$2"; shift 2 ;;
    -m|--model)
      MODEL="$2"; shift 2 ;;
    -t|--timeout)
      TIMEOUT="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      usage; exit 2 ;;
  esac
 done

if [[ -z "$API_KEY" ]]; then
  echo "Missing API key. Provide --api-key or set OPENAI_API_KEY." >&2
  exit 2
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required." >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required (sudo apt-get install -y jq)." >&2
  exit 2
fi

url="${BASE_URL%/}/models"

response_file="$(mktemp)"
http_code=$(curl -sS --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -w "%{http_code}" \
  -o "$response_file" \
  "$url" || true)

if [[ "$http_code" != "200" ]]; then
  echo "Request failed: HTTP $http_code" >&2
  cat "$response_file" >&2
  rm -f "$response_file"
  exit 1
fi

if [[ -n "$MODEL" ]]; then
  if jq -e --arg m "$MODEL" '.data[]?.id == $m' "$response_file" >/dev/null; then
    echo "OK: API key valid; model '$MODEL' found."
  else
    echo "API key valid, but model '$MODEL' not found." >&2
    rm -f "$response_file"
    exit 1
  fi
else
  count=$(jq '.data | length' "$response_file")
  echo "OK: API key valid; $count models returned."
fi

rm -f "$response_file"
