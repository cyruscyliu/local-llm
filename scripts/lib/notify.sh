#!/usr/bin/env bash
# notify.sh -- notification helpers (Discord webhook).
set -euo pipefail

discord_enabled() {
    [[ -n "${DISCORD_WEBHOOK_URL:-}" ]]
}

discord_post() {
    local content="$1"

    if ! discord_enabled; then
        return 0
    fi
    if ! command -v curl >/dev/null 2>&1; then
        echo "[WARN] curl not found; cannot send Discord notification" >&2
        return 0
    fi

    # Discord webhook content is limited (2k). Keep it tight and predictable.
    local trimmed="$content"
    if [[ "${#trimmed}" -gt 1800 ]]; then
        trimmed="${trimmed:0:1800}…"
    fi

    local payload
    payload="$(python3 -c 'import json,sys; print(json.dumps({"content": sys.argv[1]}))' "$trimmed")"
    curl -fsS -H 'Content-Type: application/json' -d "$payload" "$DISCORD_WEBHOOK_URL" >/dev/null || true
}

