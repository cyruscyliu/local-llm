#!/usr/bin/env bash
# update.sh -- Pull latest changes and apply targeted service updates.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

wait_for_service_health() {
    local svc="$1"
    local timeout_secs="$2"

    log "Waiting for $svc to be healthy..."
    timeout "$timeout_secs" bash -c "
        until docker compose ps -q $svc | xargs docker inspect --format '{{.State.Health.Status}}' 2>/dev/null | grep -q healthy; do
            sleep 3
        done
    " && log "  $svc: healthy" || log "  $svc: TIMEOUT (may still be starting)"
}

compose_service_block() {
    local ref="$1"
    local svc="$2"

    git show "${ref}:docker-compose.yml" 2>/dev/null | awk -v svc="$svc" '
        /^services:/ { in_services=1; next }
        !in_services { next }
        /^[^[:space:]]/ { exit }
        /^  [A-Za-z0-9_.-]+:/ {
            if (in_target) exit
            current=$1
            sub(/:$/, "", current)
            if (current == svc) {
                in_target=1
                print
            }
            next
        }
        in_target { print }
    '
}

service_block_changed() {
    local ref_a="$1"
    local ref_b="$2"
    local svc="$3"
    local block_a
    local block_b

    block_a="$(compose_service_block "$ref_a" "$svc")"
    block_b="$(compose_service_block "$ref_b" "$svc")"
    [[ "$block_a" != "$block_b" ]]
}

append_unique() {
    local array_name="$1"
    local value="$2"
    eval "local current=(\"\${${array_name}[@]-}\")"
    local item
    for item in "${current[@]}"; do
        [[ "$item" == "$value" ]] && return 0
    done
    eval "${array_name}+=(\"$value\")"
}

# 1. Pull latest code
log "Pulling latest changes..."
git pull --ff-only

# 2. Detect what changed since last update marker
MARKER_FILE="$REPO_ROOT/.last-restart"
if [[ -f "$MARKER_FILE" ]]; then
    LAST_SHA="$(cat "$MARKER_FILE")"
else
    LAST_SHA="HEAD~1"
fi
CURRENT_SHA="$(git rev-parse HEAD)"

if [[ "$LAST_SHA" == "$CURRENT_SHA" ]]; then
    log "No new commits since last update."
    exit 0
fi

CHANGED_FILES="$(git diff --name-only "$LAST_SHA" "$CURRENT_SHA" 2>/dev/null || git diff --name-only HEAD~1 HEAD)"
log "Changed files since last update:"
echo "$CHANGED_FILES" | sed 's/^/  /'

# 3. Map changed files to services that need restarting
RESTART_SERVICES=()
RECREATE_SERVICES=()

if echo "$CHANGED_FILES" | grep -q '^nginx/'; then
    append_unique RESTART_SERVICES nginx
fi

if echo "$CHANGED_FILES" | grep -q '^configs/litellm'; then
    append_unique RESTART_SERVICES litellm
fi

if echo "$CHANGED_FILES" | grep -q '^configs/grafana'; then
    append_unique RESTART_SERVICES grafana
fi

if echo "$CHANGED_FILES" | grep -q '^data/prometheus/prometheus.yml'; then
    append_unique RESTART_SERVICES prometheus
fi

if echo "$CHANGED_FILES" | grep -q '^docker-compose.yml'; then
    for svc in vllm litellm open-webui nginx grafana prometheus postgres redis qdrant dcgm-exporter node-exporter; do
        if service_block_changed "$LAST_SHA" "$CURRENT_SHA" "$svc"; then
            append_unique RECREATE_SERVICES "$svc"
        fi
    done
fi

# Recreate downstream services if an upstream service definition changed.
for svc in "${RECREATE_SERVICES[@]}"; do
    case "$svc" in
        vllm)
            append_unique RESTART_SERVICES litellm
            ;;
        litellm)
            append_unique RESTART_SERVICES open-webui
            append_unique RESTART_SERVICES nginx
            ;;
        open-webui)
            append_unique RESTART_SERVICES nginx
            ;;
    esac
done

# Avoid double work for services that will be recreated.
FILTERED_RESTART_SERVICES=()
for svc in "${RESTART_SERVICES[@]}"; do
    skip=false
    for recreate_svc in "${RECREATE_SERVICES[@]}"; do
        if [[ "$svc" == "$recreate_svc" ]]; then
            skip=true
            break
        fi
    done
    if [[ "$skip" == false ]]; then
        FILTERED_RESTART_SERVICES+=("$svc")
    fi
done
RESTART_SERVICES=("${FILTERED_RESTART_SERVICES[@]}")

if [[ ${#RECREATE_SERVICES[@]} -eq 0 && ${#RESTART_SERVICES[@]} -eq 0 ]]; then
    log "No service-affecting changes detected. Nothing to restart."
else
    if [[ ${#RECREATE_SERVICES[@]} -gt 0 ]]; then
        log "Recreating: ${RECREATE_SERVICES[*]}"
        for svc in "${RECREATE_SERVICES[@]}"; do
            docker compose up -d --no-deps "$svc"
            case "$svc" in
                vllm) wait_for_service_health "$svc" 300 ;;
                litellm) wait_for_service_health "$svc" 180 ;;
                open-webui) wait_for_service_health "$svc" 120 ;;
                nginx) wait_for_service_health "$svc" 60 ;;
                *) wait_for_service_health "$svc" 120 ;;
            esac
        done
    fi

    if [[ ${#RESTART_SERVICES[@]} -gt 0 ]]; then
        log "Restarting: ${RESTART_SERVICES[*]}"
        docker compose restart "${RESTART_SERVICES[@]}"

        for svc in "${RESTART_SERVICES[@]}"; do
            case "$svc" in
                vllm) wait_for_service_health "$svc" 300 ;;
                litellm) wait_for_service_health "$svc" 180 ;;
                open-webui) wait_for_service_health "$svc" 120 ;;
                nginx) wait_for_service_health "$svc" 60 ;;
                *) wait_for_service_health "$svc" 120 ;;
            esac
        done
    fi
fi

# 5. Update marker
echo "$CURRENT_SHA" > "$MARKER_FILE"
log "Update complete."
docker compose ps
