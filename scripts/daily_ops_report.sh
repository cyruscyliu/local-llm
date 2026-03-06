#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_NAME="${COMPOSE_PROJECT_NAME:-$(basename "$ROOT_DIR")}"

# Load env if present (for DISCORD webhook and DB creds)
if [[ -f "${ROOT_DIR}/.env" ]]; then
  set -a
  . "${ROOT_DIR}/.env"
  set +a
fi

DISCORD_WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-${CODING_AGENT_DISCORD_WEBHOOK_URL:-}}"
export DISCORD_WEBHOOK_URL

source "${ROOT_DIR}/scripts/lib/notify.sh"

strip_ansi() {
  sed -r 's/\x1B\[[0-9;]*[mK]//g'
}

date_yesterday="$(date -d "yesterday" +%F)"
date_today="$(date +%F)"

# 1) Config check summary
config_summary="N/A"
if [[ -x "${ROOT_DIR}/scripts/check-config.sh" ]]; then
  config_out="$(bash "${ROOT_DIR}/scripts/check-config.sh" 2>/dev/null || true)"
  config_summary="$(echo "$config_out" | strip_ansi | rg -m1 'TOTAL:' || true)"
  if [[ -z "$config_summary" ]]; then
    config_summary="N/A"
  fi
fi

# 2) Prometheus targets health
prom_targets="N/A"
if command -v curl >/dev/null 2>&1; then
  prom_json="$(curl -fsS http://localhost:9090/api/v1/targets 2>/dev/null || true)"
  if [[ -n "$prom_json" ]]; then
    prom_targets="$(python3 - <<'PY'
import json,sys
try:
    data=json.load(sys.stdin)
    bad=[]
    for t in data.get("data", {}).get("activeTargets", []):
        if t.get("health") != "up":
            bad.append(f"{t.get('labels', {}).get('job','?')}@{t.get('scrapeUrl','?')}")
    if bad:
        print("DOWN: " + ", ".join(bad))
    else:
        print("OK")
except Exception:
    print("N/A")
PY
<<<"$prom_json")"
  fi
fi

# 3) Container health
container_issues="N/A"
if command -v docker >/dev/null 2>&1; then
  container_issues="$(docker ps -a \
    --filter "label=com.docker.compose.project=${PROJECT_NAME}" \
    --format '{{.Names}}\t{{.Status}}' | rg -i 'unhealthy|exited|dead|restarting' || true)"
  if [[ -z "$container_issues" ]]; then
    container_issues="OK"
  fi
fi

# 4) Image list (current)
image_summary="N/A"
if command -v docker >/dev/null 2>&1; then
  image_summary="$(docker compose images 2>/dev/null | tail -n +2 | awk '{printf "%s:%s ", $1, $2}' || true)"
  if [[ -z "$image_summary" ]]; then
    image_summary="N/A"
  fi
fi

msg=$(
  cat <<EOF
Daily Ops Report (${date_yesterday})
Config: ${config_summary}
Observability: Prometheus Targets = ${prom_targets}
Maintenance: ${container_issues}
Updates: Current images = ${image_summary}
EOF
)

discord_post "$msg"
echo "$msg"
