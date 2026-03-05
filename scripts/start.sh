#!/usr/bin/env bash
# start.sh -- Bring up the full local-llm platform and wait for health.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# 1. Pull latest images
log "Pulling images..."
docker-compose pull

# 2. Fix data directory permissions
log "Fixing data directory permissions..."
mkdir -p data/prometheus data/grafana data/qdrant
sudo chown -R 65534:65534 data/prometheus
sudo chown -R 472:472 data/grafana
sudo chown -R 1000:1000 data/qdrant

# 3. Start infrastructure first (no GPU needed)
log "Starting infrastructure (postgres, redis, qdrant, prometheus, node-exporter, grafana)..."
docker-compose up -d postgres redis qdrant prometheus node-exporter grafana

log "Waiting for infrastructure to be healthy..."
for svc in postgres redis qdrant prometheus node-exporter grafana; do
    timeout 120 bash -c "
        until docker-compose ps -q $svc | xargs docker inspect --format '{{.State.Health.Status}}' 2>/dev/null | grep -q healthy; do
            sleep 2
        done
    " && log "  $svc: healthy" || log "  $svc: TIMEOUT (continuing anyway)"
done

# 3. Start GPU services
log "Starting GPU services (vllm, dcgm-exporter)..."
docker-compose up -d vllm dcgm-exporter

log "Waiting for vllm to load model (this may take a few minutes)..."
timeout 300 bash -c '
    until docker-compose ps -q vllm | xargs docker inspect --format "{{.State.Health.Status}}" 2>/dev/null | grep -q healthy; do
        sleep 5
    done
' && log "  vllm: healthy" || log "  vllm: TIMEOUT (may still be loading)"

# 4. Start LiteLLM (depends on postgres, redis, vllm)
log "Starting litellm..."
docker-compose up -d litellm

timeout 180 bash -c '
    until docker-compose ps -q litellm | xargs docker inspect --format "{{.State.Health.Status}}" 2>/dev/null | grep -q healthy; do
        sleep 5
    done
' && log "  litellm: healthy" || log "  litellm: TIMEOUT"

# 5. Start Open WebUI (depends on litellm)
log "Starting open-webui..."
docker-compose up -d open-webui

timeout 120 bash -c '
    until docker-compose ps -q open-webui | xargs docker inspect --format "{{.State.Health.Status}}" 2>/dev/null | grep -q healthy; do
        sleep 5
    done
' && log "  open-webui: healthy" || log "  open-webui: TIMEOUT"

# 6. Start nginx (depends on open-webui, litellm)
log "Starting nginx..."
docker-compose up -d nginx

timeout 60 bash -c '
    until docker-compose ps -q nginx | xargs docker inspect --format "{{.State.Health.Status}}" 2>/dev/null | grep -q healthy; do
        sleep 3
    done
' && log "  nginx: healthy" || log "  nginx: TIMEOUT"

# 7. Summary
log ""
log "=== Platform Status ==="
docker-compose ps
log ""
SERVER_IP="$(hostname -I | awk '{print $1}')"
log "Access:"
log "  Open WebUI:  http://${SERVER_IP}/"
log "  LiteLLM API: http://${SERVER_IP}:4000/"
log "  Grafana:     http://${SERVER_IP}:3001/"
log "  Prometheus:  http://${SERVER_IP}:9090/"
