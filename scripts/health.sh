#!/usr/bin/env bash
# health.sh -- Check health status of all services.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

SERVICES=(postgres redis qdrant vllm litellm open-webui nginx prometheus node-exporter grafana dcgm-exporter)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

printf "%-20s %-12s %-10s %s\n" "SERVICE" "STATE" "HEALTH" "PORTS"
printf "%-20s %-12s %-10s %s\n" "-------" "-----" "------" "-----"

all_healthy=true

for svc in "${SERVICES[@]}"; do
    cid="$(docker-compose ps -q "$svc" 2>/dev/null)" || true

    if [[ -z "$cid" ]]; then
        printf "%-20s ${YELLOW}%-12s${NC} %-10s %s\n" "$svc" "not found" "-" "-"
        all_healthy=false
        continue
    fi

    state="$(docker inspect --format '{{.State.Status}}' "$cid" 2>/dev/null)" || state="unknown"
    health="$(docker inspect --format '{{.State.Health.Status}}' "$cid" 2>/dev/null)" || health="none"
    ports="$(docker inspect --format '{{range $p, $conf := .NetworkSettings.Ports}}{{if $conf}}{{$p}}->{{(index $conf 0).HostPort}} {{end}}{{end}}' "$cid" 2>/dev/null)" || ports=""

    case "$health" in
        healthy)   color="$GREEN" ;;
        unhealthy) color="$RED"; all_healthy=false ;;
        starting)  color="$YELLOW"; all_healthy=false ;;
        *)         color="$NC" ;;
    esac

    if [[ "$state" != "running" ]]; then
        color="$RED"
        all_healthy=false
    fi

    printf "%-20s %-12s ${color}%-10s${NC} %s\n" "$svc" "$state" "$health" "$ports"
done

echo ""
if $all_healthy; then
    echo -e "${GREEN}All services healthy.${NC}"
else
    echo -e "${RED}Some services are not healthy.${NC}"
    exit 1
fi
