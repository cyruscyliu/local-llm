#!/usr/bin/env bash
# restart.sh -- Pull latest changes and restart affected services.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# 1. Pull latest code
log "Pulling latest changes..."
git pull --ff-only

# 2. Detect what changed since last restart marker
MARKER_FILE="$REPO_ROOT/.last-restart"
if [[ -f "$MARKER_FILE" ]]; then
    LAST_SHA="$(cat "$MARKER_FILE")"
else
    LAST_SHA="HEAD~1"
fi
CURRENT_SHA="$(git rev-parse HEAD)"

if [[ "$LAST_SHA" == "$CURRENT_SHA" ]]; then
    log "No new commits since last restart."
    exit 0
fi

CHANGED_FILES="$(git diff --name-only "$LAST_SHA" "$CURRENT_SHA" 2>/dev/null || git diff --name-only HEAD~1 HEAD)"
log "Changed files since last restart:"
echo "$CHANGED_FILES" | sed 's/^/  /'

# 3. Map changed files to services that need restarting
RESTART_SERVICES=()

if echo "$CHANGED_FILES" | grep -q '^nginx/'; then
    RESTART_SERVICES+=(nginx)
fi

if echo "$CHANGED_FILES" | grep -q '^configs/litellm'; then
    RESTART_SERVICES+=(litellm)
fi

if echo "$CHANGED_FILES" | grep -q '^configs/grafana'; then
    RESTART_SERVICES+=(grafana)
fi

if echo "$CHANGED_FILES" | grep -q '^data/prometheus/prometheus.yml'; then
    RESTART_SERVICES+=(prometheus)
fi

if echo "$CHANGED_FILES" | grep -q '^docker-compose.yml'; then
    # Full recreate if compose file changed
    log "docker-compose.yml changed -- recreating all services..."
    docker-compose up -d
    echo "$CURRENT_SHA" > "$MARKER_FILE"
    log "Done."
    exit 0
fi

# 4. Restart only affected services
if [[ ${#RESTART_SERVICES[@]} -eq 0 ]]; then
    log "No service-affecting changes detected. Nothing to restart."
else
    log "Restarting: ${RESTART_SERVICES[*]}"
    docker-compose restart "${RESTART_SERVICES[@]}"

    # Wait for restarted services to be healthy
    for svc in "${RESTART_SERVICES[@]}"; do
        log "Waiting for $svc to be healthy..."
        timeout 120 bash -c "
            until docker-compose ps -q $svc | xargs docker inspect --format '{{.State.Health.Status}}' 2>/dev/null | grep -q healthy; do
                sleep 3
            done
        " && log "  $svc: healthy" || log "  $svc: TIMEOUT (may still be starting)"
    done
fi

# 5. Update marker
echo "$CURRENT_SHA" > "$MARKER_FILE"
log "Restart complete."
docker-compose ps
