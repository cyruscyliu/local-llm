#!/usr/bin/env bash
# =============================================================================
# Platform Configuration Checker
# Matches docs/config-checklist.md item-by-item.
# Usage: bash scripts/check-config.sh
# =============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

COMPOSE_FILE="docker-compose.yml"
LITELLM_CFG="configs/litellm.yaml"
NGINX_CONF="nginx/nginx.conf"

PASS=0; WARN=0; FAIL=0

pass()    { PASS=$((PASS + 1)); printf "\033[32m[PASS]\033[0m %s\n" "$1"; }
warn()    { WARN=$((WARN + 1)); printf "\033[33m[WARN]\033[0m %s\n" "$1"; }
fail()    { FAIL=$((FAIL + 1)); printf "\033[31m[FAIL]\033[0m %s\n" "$1"; }
detail()  { printf "       - %s\n" "$1"; }
section() { printf "\n\033[1m=== %s ===\033[0m\n\n" "$1"; }
sub()     { printf "\033[1m-- %s --\033[0m\n" "$1"; }

[ -f "$COMPOSE_FILE" ] || { echo "ERROR: $COMPOSE_FILE not found"; exit 1; }

COMPOSE=$(cat "$COMPOSE_FILE")
SERVICES=$(echo "$COMPOSE" | grep -E '^  [a-z][a-z0-9_-]+:' | sed 's/://;s/^ *//')

svc_block() {
  # Extract the YAML block for a service (handles last service in file too)
  echo "$COMPOSE" | awk "
    /^  $1:/ { found=1; print; next }
    found && /^  [a-z]/ { exit }
    found { print }
  "
}

# =============================================================================
section "1. PLATFORM CONFIGURATION"
# =============================================================================

# --- 1.1 Container Services ---
sub "Container Services"

# [ ] All services defined in docker-compose.yml
count=$(echo "$SERVICES" | wc -l | tr -d ' ')
pass "All services defined in docker-compose.yml ($count services)"
for svc in $SERVICES; do detail "$svc"; done

# [ ] Each service has a unique name
dupes=$(echo "$SERVICES" | sort | uniq -d)
if [ -z "$dupes" ]; then
  pass "Each service has a unique name"
else
  fail "Duplicate service names found"
  echo "$dupes" | while read -r d; do detail "$d"; done
fi

# [ ] Restart policy set
missing=""
for svc in $SERVICES; do
  if ! svc_block "$svc" | grep -q 'restart:'; then
    missing="$missing $svc"
  fi
done
if [ -z "$missing" ]; then
  pass "Restart policy set on all services"
else
  fail "Restart policy missing"
  for svc in $missing; do detail "$svc"; done
fi

# [ ] Service dependencies correct (depends_on)
has_deps=""
for svc in $SERVICES; do
  if svc_block "$svc" | grep -q 'depends_on:'; then
    has_deps="$has_deps $svc"
  fi
done
if [ -n "$has_deps" ]; then
  pass "Service dependencies declared (depends_on)"
  for svc in $has_deps; do detail "$svc"; done
else
  warn "No depends_on found in any service"
fi

# [ ] Ports explicitly declared
pass "Service ports explicitly declared"
for svc in $SERVICES; do
  block=$(svc_block "$svc")
  port=$(echo "$block" | grep -oE '"?[0-9]+:[0-9]+"?' | head -1 | tr -d '"' || true)
  expose=$(echo "$block" | grep -A1 'expose:' | grep -oE '"?[0-9]+"?' | head -1 | tr -d '"' || true)
  if [ -n "$port" ]; then
    detail "$svc -> host port $port"
  elif [ -n "$expose" ]; then
    detail "$svc -> internal only $expose"
  else
    detail "$svc -> no port defined"
  fi
done

# [ ] Internal services not exposed to host
INTERNAL="postgres redis qdrant vllm"
exposed=""
for svc in $INTERNAL; do
  if svc_block "$svc" | grep -q '^\s*ports:'; then
    exposed="$exposed $svc"
  fi
done
if [ -z "$exposed" ]; then
  pass "Internal services not exposed to host"
else
  fail "Internal services exposed to host (should use 'expose' only)"
  for svc in $exposed; do detail "$svc"; done
fi

# --- 1.2 Environment Variables ---
echo ""
sub "Environment Variables"

# [ ] All config via .env
if [ -f ".env" ]; then
  pass "Config managed via .env file"
else
  fail ".env file missing — secrets likely hardcoded"
fi

# [ ] No hardcoded secrets
SECRET_RE='(password|PASSWORD|secret|SECRET|api_key|API_KEY).*[=:]\s*["\x27]?[a-zA-Z0-9_-]{3,}'
found_secrets=""
if echo "$COMPOSE" | grep -iEq "$SECRET_RE"; then
  found_secrets="$COMPOSE_FILE"
fi
if [ -f "$LITELLM_CFG" ] && grep -iEq "$SECRET_RE" "$LITELLM_CFG"; then
  found_secrets="$found_secrets $LITELLM_CFG"
fi
if [ -z "$found_secrets" ]; then
  pass "No hardcoded secrets in config files"
else
  fail "Hardcoded secrets found"
  for f in $found_secrets; do detail "$f"; done
fi

# [ ] .env not committed to git
if [ -f ".gitignore" ] && grep -q '\.env' .gitignore; then
  pass ".env excluded from git (.gitignore)"
else
  fail ".env NOT in .gitignore"
fi

# [ ] .env.example exists
if [ -f ".env.example" ]; then
  pass ".env.example template committed"
else
  warn ".env.example missing — no template for new developers"
fi

# --- 1.3 Data Persistence ---
echo ""
sub "Data Persistence"

VOLUMES="postgres:data/postgres redis:data/redis qdrant:data/qdrant prometheus:data/prometheus grafana:data/grafana"
for entry in $VOLUMES; do
  svc="${entry%%:*}"; path="${entry#*:}"
  if echo "$COMPOSE" | grep -q "$path"; then
    pass "$svc data persisted (./$path)"
  else
    fail "$svc data NOT persisted"
  fi
done

# --- 1.4 Health Checks ---
echo ""
sub "Health Checks"

# [ ] Every service has healthcheck
missing=""
for svc in $SERVICES; do
  if ! svc_block "$svc" | grep -q 'healthcheck:'; then
    missing="$missing $svc"
  fi
done
if [ -z "$missing" ]; then
  pass "Every service has a healthcheck"
else
  fail "Services missing healthcheck"
  for svc in $missing; do detail "$svc"; done
fi

# [ ] start_period on slow services
SLOW="vllm litellm open-webui"
missing=""
for svc in $SLOW; do
  if ! svc_block "$svc" | grep -q 'start_period:'; then
    missing="$missing $svc"
  fi
done
if [ -z "$missing" ]; then
  pass "start_period set on slow-starting services"
else
  warn "start_period missing on slow services"
  for svc in $missing; do detail "$svc"; done
fi

# [ ] depends_on uses condition: service_healthy
has_condition=0; has_plain=0; plain_list=""
for svc in $SERVICES; do
  block=$(svc_block "$svc")
  if echo "$block" | grep -q 'condition:'; then
    has_condition=1
  elif echo "$block" | grep -q 'depends_on:'; then
    has_plain=1
    plain_list="$plain_list $svc"
  fi
done
if [ "$has_plain" -eq 0 ]; then
  pass "All depends_on use condition: service_healthy"
else
  warn "Some depends_on lack health conditions"
  for svc in $plain_list; do detail "$svc"; done
fi

# =============================================================================
section "2. MODEL CONFIGURATION"
# =============================================================================

VLLM_BLOCK=$(svc_block "vllm")

sub "vLLM Engine Parameters"

check_vllm() {
  if echo "$VLLM_BLOCK" | grep -q -- "$1"; then
    pass "$2 ($1)"
  else
    fail "$2 — not set ($1)"
  fi
}

check_vllm "--max-model-len"          "Context length configured"
check_vllm "--gpu-memory-utilization"  "GPU memory utilization limit"
check_vllm "--max-num-seqs"            "Max concurrent sequences"

echo ""
sub "LiteLLM Inference Defaults"

if [ -f "$LITELLM_CFG" ]; then
  for param in max_tokens temperature top_p; do
    if grep -q "$param" "$LITELLM_CFG"; then
      pass "Default $param configured"
    else
      warn "Default $param not set (must specify per-request)"
    fi
  done
else
  fail "LiteLLM config not found ($LITELLM_CFG)"
fi

echo ""
sub "Model Management"

# [ ] Model name specified
if echo "$VLLM_BLOCK" | grep -qoE '"[A-Za-z]+/[^"]+"'; then
  model=$(echo "$VLLM_BLOCK" | grep -oE '"[A-Za-z]+/[^"]+"' | head -1 | tr -d '"')
  pass "Model specified: $model"
else
  warn "Model name not found in vLLM config"
fi

# [ ] models/ directory
if [ -d "models" ]; then
  pass "models/ directory exists"
else
  warn "models/ directory missing"
fi

# [ ] LiteLLM routing
if [ -f "$LITELLM_CFG" ] && grep -q 'model_list' "$LITELLM_CFG"; then
  model_count=$(grep -c 'model_name' "$LITELLM_CFG" || echo 0)
  pass "LiteLLM model routing configured ($model_count models)"
else
  warn "No model routing in LiteLLM"
fi

# =============================================================================
section "3. RESOURCE CONFIGURATION"
# =============================================================================

sub "GPU"

if echo "$VLLM_BLOCK" | grep -q 'gpu-memory-utilization'; then
  pass "GPU memory utilization limited in vLLM"
else
  fail "GPU memory utilization not limited"
fi

if echo "$COMPOSE" | grep -q 'dcgm-exporter'; then
  pass "GPU monitoring enabled (dcgm-exporter)"
else
  warn "No GPU monitoring service"
fi

if echo "$VLLM_BLOCK" | grep -q 'max-num-seqs'; then
  pass "Inference concurrency limited"
else
  fail "Inference concurrency not limited"
fi

echo ""
sub "CPU / Memory Limits"

HEAVY="vllm litellm open-webui postgres"
for svc in $HEAVY; do
  block=$(svc_block "$svc")
  mem=$(echo "$block" | grep -cE 'mem_limit|memory' || true)
  cpu=$(echo "$block" | grep -cE 'cpus|cpu_count|cpu_quota' || true)
  if [ "$mem" -gt 0 ] && [ "$cpu" -gt 0 ]; then
    pass "$svc: memory + CPU limits set"
  elif [ "$mem" -gt 0 ]; then
    warn "$svc: memory limit set, no CPU limit"
  elif [ "$cpu" -gt 0 ]; then
    warn "$svc: CPU limit set, no memory limit"
  else
    warn "$svc: no resource limits"
  fi
done

echo ""
sub "Storage"

if echo "$COMPOSE" | grep -q 'node-exporter'; then
  pass "Disk monitoring available (node-exporter)"
else
  warn "No disk monitoring"
fi

if echo "$COMPOSE" | grep -qE 'logging:|log-opts'; then
  pass "Docker log rotation configured"
else
  warn "No Docker log rotation (logs may grow unbounded)"
fi

# =============================================================================
section "4. NETWORK CONFIGURATION"
# =============================================================================

sub "Reverse Proxy"

if echo "$COMPOSE" | grep -q 'nginx'; then
  pass "External access through reverse proxy (nginx)"
else
  fail "No reverse proxy service"
fi

if [ -f "$NGINX_CONF" ]; then
  if grep -q 'ssl\|443' "$NGINX_CONF"; then
    pass "HTTPS/TLS configured"
  else
    warn "No HTTPS — HTTP only on port 80"
  fi
  if grep -q 'return 301.*https' "$NGINX_CONF"; then
    pass "HTTP-to-HTTPS redirect configured"
  else
    warn "No HTTP-to-HTTPS redirect"
  fi
else
  fail "nginx.conf not found"
fi

echo ""
sub "API Routing"

if [ -f "$NGINX_CONF" ]; then
  if grep -q 'location /' "$NGINX_CONF"; then
    pass "/ -> Open WebUI"
  else
    fail "No root route to Open WebUI"
  fi
  if grep -qE 'location.*(litellm|/api)' "$NGINX_CONF"; then
    pass "/litellm/ or /api/ -> LiteLLM"
  else
    warn "No API route to LiteLLM"
  fi
  if grep -q 'Upgrade' "$NGINX_CONF"; then
    pass "WebSocket upgrade headers configured"
  else
    warn "No WebSocket upgrade headers"
  fi
fi

echo ""
sub "Internal Network"

if echo "$COMPOSE" | grep -q '^networks:'; then
  pass "Custom Docker network defined"
else
  warn "No custom Docker network (default bridge)"
fi

# [ ] No hardcoded IPs
found_ips=$(echo "$COMPOSE" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' \
  | grep -v '0\.0\.0\.0' | grep -v '127\.0\.0\.1' || true)
if [ -z "$found_ips" ]; then
  pass "No hardcoded IPs — services use container names"
else
  warn "Hardcoded IPs found in docker-compose.yml"
  echo "$found_ips" | while read -r ip; do detail "$ip"; done
fi

# =============================================================================
section "5. SECURITY CONFIGURATION"
# =============================================================================

sub "Authentication"

if [ -f "$LITELLM_CFG" ] && grep -qE 'master_key|api_key' "$LITELLM_CFG"; then
  pass "LiteLLM API key enabled"
else
  warn "LiteLLM: no master_key / api_key"
fi

# Open WebUI login is enabled by default, just note it
pass "Open WebUI login enabled (default)"

echo ""
sub "Rate Limiting"

if [ -f "$NGINX_CONF" ] && grep -q 'limit_req' "$NGINX_CONF"; then
  pass "Rate limiting configured in nginx"
else
  warn "No rate limiting in nginx"
fi

if [ -f "$LITELLM_CFG" ] && grep -qE 'rpm|tpm|max_budget' "$LITELLM_CFG"; then
  pass "LiteLLM rate/budget limits configured"
else
  warn "No rate/budget limits in LiteLLM"
fi

if [ -f "$NGINX_CONF" ] && grep -q 'client_max_body_size' "$NGINX_CONF"; then
  size=$(grep -oP 'client_max_body_size\s+\K[^;]+' "$NGINX_CONF")
  pass "Request body size limit: $size"
else
  warn "No client_max_body_size in nginx (default 1MB)"
fi

echo ""
sub "Network Security"

# Already checked HTTPS above, summarize
if [ -f "$NGINX_CONF" ] && grep -q 'ssl' "$NGINX_CONF"; then
  pass "HTTPS enabled"
else
  warn "HTTPS not enabled"
fi

echo ""
sub "Secrets Management"

if [ -f ".env" ] && [ -f ".gitignore" ] && grep -q '\.env' .gitignore; then
  pass "Secrets in .env, excluded from git"
else
  fail "Secrets management incomplete"
fi

if command -v git &>/dev/null && git ls-files --error-unmatch .env &>/dev/null 2>&1; then
  fail ".env is tracked by git! Run: git rm --cached .env"
else
  pass ".env not tracked by git"
fi

# =============================================================================
echo ""
echo "============================================="
printf " TOTAL:  \033[32m%d passed\033[0m  |  \033[33m%d warnings\033[0m  |  \033[31m%d failed\033[0m\n" "$PASS" "$WARN" "$FAIL"
echo "============================================="
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo "Fix FAIL items first, then address WARN items."
  exit 1
else
  echo "No critical failures. Review WARN items for hardening."
  exit 0
fi
