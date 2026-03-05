#!/usr/bin/env bash
# coding-agent-wrapper.sh -- Wrapper for running the coding agent via cron/systemd.
#
# Features:
#   - Lock file prevents concurrent runs
#   - Hard timeout for the entire session
#   - Logging to data/coding-agent/agent.log
#
# Usage:
#   ./scripts/coding-agent-wrapper.sh                    # single task, default backend
#   ./scripts/coding-agent-wrapper.sh --loop             # loop mode
#   ./scripts/coding-agent-wrapper.sh --backend gemini   # specific backend
#
# Cron example (run nightly at 10pm, loop for up to 6 hours):
#   0 22 * * * cd /path/to/repo && CODING_AGENT_SESSION_TIMEOUT=6h ./scripts/coding-agent-wrapper.sh --loop
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK_FILE="${REPO_ROOT}/data/coding-agent/agent.lock"
LOG_DIR="${REPO_ROOT}/data/coding-agent"
LOG_FILE="${LOG_DIR}/agent.log"
SESSION_TIMEOUT="${CODING_AGENT_SESSION_TIMEOUT:-6h}"

mkdir -p "$LOG_DIR"

# ── Lock file ───────────────────────────────────────────────────────

cleanup() {
    rm -f "$LOCK_FILE"
}

if [[ -f "$LOCK_FILE" ]]; then
    local_pid="$(cat "$LOCK_FILE" 2>/dev/null || echo "")"
    if [[ -n "$local_pid" ]] && kill -0 "$local_pid" 2>/dev/null; then
        echo "Another agent is running (pid ${local_pid}). Exiting." >&2
        exit 1
    fi
    echo "Stale lock file found, removing." >&2
    rm -f "$LOCK_FILE"
fi

echo $$ > "$LOCK_FILE"
trap cleanup EXIT

# ── Run ─────────────────────────────────────────────────────────────

echo "=== Coding agent session started at $(date -Iseconds) ===" | tee -a "$LOG_FILE"
echo "Session timeout: ${SESSION_TIMEOUT}" | tee -a "$LOG_FILE"

export CODING_AGENT_LOG="$LOG_FILE"

timeout "$SESSION_TIMEOUT" "${REPO_ROOT}/scripts/coding-agent.sh" "$@" 2>&1 | tee -a "$LOG_FILE"
exit_code=${PIPESTATUS[0]}

echo "=== Coding agent session ended at $(date -Iseconds) (exit: ${exit_code}) ===" | tee -a "$LOG_FILE"
exit "$exit_code"
