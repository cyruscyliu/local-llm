#!/usr/bin/env bash
# task_utils.sh -- Shell helpers for working with tasks/status.json
# Wraps scripts/tasks.py for use in shell scripts.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TASKS_PY="${REPO_ROOT}/scripts/tasks.py"
STATUS_JSON="${REPO_ROOT}/tasks/status.json"

# ── status.json operations ──────────────────────────────────────────

get_next_task() {
    python3 "$TASKS_PY" --status-file "$STATUS_JSON" next 2>/dev/null || echo ""
}

get_runnable_tasks() {
    python3 "$TASKS_PY" --status-file "$STATUS_JSON" runnable 2>/dev/null
}

update_task_status() {
    local task_id="$1" status="$2"
    local error="${3:-}"
    if [[ -n "$error" ]]; then
        python3 "$TASKS_PY" --status-file "$STATUS_JSON" set "$task_id" "$status" --error "$error"
    else
        python3 "$TASKS_PY" --status-file "$STATUS_JSON" set "$task_id" "$status"
    fi
}

record_outputs() {
    local task_id="$1"
    shift
    # remaining args are KEY=VALUE pairs
    python3 "$TASKS_PY" --status-file "$STATUS_JSON" output "$task_id" "$@"
}

get_task_outputs() {
    local task_id="$1"
    python3 -c "
import json, sys
with open('$STATUS_JSON') as f:
    data = json.load(f)
for t in data['tasks']:
    if t['id'] == '$task_id':
        for k, v in t.get('outputs', {}).items():
            print(f'{k}={v}')
        break
"
}

check_dependencies() {
    local task_id="$1"
    python3 -c "
import json, sys
with open('$STATUS_JSON') as f:
    data = json.load(f)
idx = {t['id']: t for t in data['tasks']}
task = idx.get('$task_id')
if not task:
    sys.exit(1)
for dep in task.get('depends_on', []):
    d = idx.get(dep)
    if not d or d['status'] != 'done':
        print(f'UNMET: {dep} ({d[\"status\"] if d else \"not found\"})')
        sys.exit(1)
print('OK')
"
}

get_task_retries() {
    local task_id="$1"
    python3 -c "
import json
with open('$STATUS_JSON') as f:
    data = json.load(f)
for t in data['tasks']:
    if t['id'] == '$task_id':
        print(t.get('retries', 0))
        break
"
}

get_task_max_retries() {
    local task_id="$1"
    python3 -c "
import json
with open('$STATUS_JSON') as f:
    data = json.load(f)
for t in data['tasks']:
    if t['id'] == '$task_id':
        print(t.get('max_retries', 3))
        break
"
}

increment_retries() {
    local task_id="$1"
    python3 -c "
import json, os, tempfile
with open('$STATUS_JSON') as f:
    data = json.load(f)
for t in data['tasks']:
    if t['id'] == '$task_id':
        t['retries'] = t.get('retries', 0) + 1
        break
fd, tmp = tempfile.mkstemp(dir=os.path.dirname('$STATUS_JSON'))
with os.fdopen(fd, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
os.replace(tmp, '$STATUS_JSON')
"
}

reset_task() {
    local task_id="$1"
    python3 "$TASKS_PY" --status-file "$STATUS_JSON" reset "$task_id"
}

# ── task file parsing ───────────────────────────────────────────────

get_task_file() {
    local task_id="$1"
    echo "${REPO_ROOT}/tasks/${task_id}.md"
}

extract_verification() {
    local task_file="$1"
    # Extract content of the first ```bash block after "## Verification"
    python3 -c "
import re, sys
with open('$task_file') as f:
    content = f.read()
m = re.search(r'## Verification.*?\`\`\`bash\n(.*?)\`\`\`', content, re.DOTALL)
if m:
    print(m.group(1).strip())
else:
    sys.exit(1)
"
}

# ── logging ─────────────────────────────────────────────────────────

log() {
    local level="$1"
    shift
    echo "[$(date -Iseconds)] [$level] $*"
}

log_info()  { log INFO  "$@"; }
log_warn()  { log WARN  "$@"; }
log_error() { log ERROR "$@"; }
