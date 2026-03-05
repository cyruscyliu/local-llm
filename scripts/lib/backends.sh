#!/usr/bin/env bash
# backends.sh -- LLM backend adapters for the coding agent.
#
# Each backend function takes a prompt on stdin and runs the appropriate CLI.
# Add new backends by defining a run_backend_<name>() function.
set -euo pipefail

# ── Claude (Anthropic) ──────────────────────────────────────────────
# Uses: claude CLI (Claude Code)
# Install: npm install -g @anthropic-ai/claude-code
run_backend_claude() {
    local task_timeout="$1"
    timeout "$task_timeout" claude --print --dangerously-skip-permissions
}

# ── Gemini (Google) ─────────────────────────────────────────────────
# Uses: gemini CLI
# Install: pip install google-generativeai
# Expects GEMINI_API_KEY in environment.
run_backend_gemini() {
    local task_timeout="$1"
    # gemini CLI reads from stdin with --prompt flag or piped input
    if command -v gemini &>/dev/null; then
        timeout "$task_timeout" gemini
    else
        # Fallback: use the Python SDK directly
        local prompt
        prompt="$(cat)"
        timeout "$task_timeout" python3 -c "
import google.generativeai as genai
import os, sys
genai.configure(api_key=os.environ['GEMINI_API_KEY'])
model = genai.GenerativeModel('gemini-2.5-flash')
response = model.generate_content(sys.stdin.read())
print(response.text)
" <<< "$prompt"
    fi
}

# ── Codex (OpenAI) ──────────────────────────────────────────────────
# Uses: codex CLI (OpenAI Codex)
# Install: npm install -g @openai/codex
# Expects OPENAI_API_KEY in environment.
run_backend_codex() {
    local task_timeout="$1"
    timeout "$task_timeout" codex --approval-mode full-auto
}

# ── Aider ───────────────────────────────────────────────────────────
# Uses: aider CLI
# Install: pip install aider-chat
run_backend_aider() {
    local task_timeout="$1"
    local prompt
    prompt="$(cat)"
    timeout "$task_timeout" aider --yes --message "$prompt"
}

# ── Custom / generic ────────────────────────────────────────────────
# Set CODING_AGENT_CUSTOM_CMD to any command that reads a prompt from stdin.
run_backend_custom() {
    local task_timeout="$1"
    if [[ -z "${CODING_AGENT_CUSTOM_CMD:-}" ]]; then
        echo "ERROR: backend 'custom' requires CODING_AGENT_CUSTOM_CMD to be set" >&2
        return 1
    fi
    timeout "$task_timeout" $CODING_AGENT_CUSTOM_CMD
}

# ── Dispatcher ──────────────────────────────────────────────────────

run_backend() {
    local backend="$1"
    local task_timeout="$2"

    local fn="run_backend_${backend}"
    if ! declare -f "$fn" &>/dev/null; then
        echo "ERROR: unknown backend '${backend}'" >&2
        echo "Available backends: claude, gemini, codex, aider, custom" >&2
        return 1
    fi

    "$fn" "$task_timeout"
}
