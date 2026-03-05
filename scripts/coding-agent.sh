#!/usr/bin/env bash
# coding-agent.sh -- Autonomous coding agent loop.
#
# Picks the next runnable task from tasks/status.json, invokes an LLM
# backend to implement it, runs verification, updates status, and commits.
#
# Supports multiple backends: claude, gemini, codex, aider, custom.
#
# Usage:
#   ./scripts/coding-agent.sh                        # run one task (default backend)
#   ./scripts/coding-agent.sh --backend gemini       # use Gemini backend
#   ./scripts/coding-agent.sh --backend codex --loop # loop with Codex
#   ./scripts/coding-agent.sh --dry-run              # show what would run
#   ./scripts/coding-agent.sh --task ID              # run a specific task
#   ./scripts/coding-agent.sh --list-backends        # show available backends
#   ./scripts/coding-agent.sh --no-bootstrap         # disable auto task-plan bootstrap
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${REPO_ROOT}/scripts/lib/task_utils.sh"
source "${REPO_ROOT}/scripts/lib/backends.sh"
source "${REPO_ROOT}/scripts/lib/notify.sh"

# ── Configuration ───────────────────────────────────────────────────

CONFIG_FILE="${REPO_ROOT}/configs/coding-agent.yaml"

# Defaults (overridden by config file, environment, or CLI flags)
BACKEND="${CODING_AGENT_BACKEND:-claude}"
GIT_BRANCH_PREFIX="${CODING_AGENT_BRANCH_PREFIX:-task/}"
AUTO_COMMIT="${CODING_AGENT_AUTO_COMMIT:-true}"
TASK_TIMEOUT="${CODING_AGENT_TASK_TIMEOUT:-30m}"
LOG_FILE="${CODING_AGENT_LOG:-}"
DISCORD_WEBHOOK_URL="${CODING_AGENT_DISCORD_WEBHOOK_URL:-}"
DISCORD_NOTIFY_ON_BLOCKED="${CODING_AGENT_DISCORD_NOTIFY_ON_BLOCKED:-true}"
DISCORD_NOTIFY_ON_FAILED="${CODING_AGENT_DISCORD_NOTIFY_ON_FAILED:-false}"
DISCORD_NOTIFY_ON_DONE="${CODING_AGENT_DISCORD_NOTIFY_ON_DONE:-false}"

# Parse config file if it exists (simple key: value YAML)
if [[ -f "$CONFIG_FILE" ]]; then
    while IFS=': ' read -r key value; do
        [[ -z "$key" || "$key" == \#* ]] && continue
        value="${value#\"}" ; value="${value%\"}"
        value="${value#\'}" ; value="${value%\'}"
        case "$key" in
            backend)            BACKEND="$value" ;;
            git_branch_prefix)  GIT_BRANCH_PREFIX="$value" ;;
            auto_commit)        AUTO_COMMIT="$value" ;;
            task_timeout)       TASK_TIMEOUT="$value" ;;
            log_file)           LOG_FILE="$value" ;;
            discord_webhook_url)             DISCORD_WEBHOOK_URL="$value" ;;
            discord_notify_on_blocked)       DISCORD_NOTIFY_ON_BLOCKED="$value" ;;
            discord_notify_on_failed)        DISCORD_NOTIFY_ON_FAILED="$value" ;;
            discord_notify_on_done)          DISCORD_NOTIFY_ON_DONE="$value" ;;
        esac
    done < "$CONFIG_FILE"
fi

# ── CLI flags ───────────────────────────────────────────────────────

DRY_RUN=false
LOOP=false
SPECIFIC_TASK=""
AUTO_BOOTSTRAP=true

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)       DRY_RUN=true; shift ;;
        --loop)          LOOP=true; shift ;;
        --task)          SPECIFIC_TASK="$2"; shift 2 ;;
        --backend|-b)    BACKEND="$2"; shift 2 ;;
        --no-bootstrap)  AUTO_BOOTSTRAP=false; shift ;;
        --list-backends)
            echo "Available backends: claude, gemini, codex, aider, custom"
            echo ""
            echo "Configure via:"
            echo "  --backend <name>              CLI flag"
            echo "  CODING_AGENT_BACKEND=<name>   environment variable"
            echo "  backend: <name>               in configs/coding-agent.yaml"
            exit 0
            ;;
        -h|--help)
            cat <<'HELP'
Usage: coding-agent.sh [OPTIONS]

Options:
  --backend, -b NAME   LLM backend (claude, gemini, codex, aider, custom)
  --task TASK_ID       Run a specific task instead of the next runnable one
  --loop               Keep running until no more tasks are runnable
  --dry-run            Show what would happen without executing
  --no-bootstrap       Do not auto-create tasks/00_generate_task_plan when tasks are missing
  --list-backends      Show available backends and exit
  -h, --help           Show this help

Environment:
  CODING_AGENT_BACKEND          Backend name (default: claude)
  CODING_AGENT_TASK_TIMEOUT     Per-task timeout (default: 30m)
  CODING_AGENT_AUTO_COMMIT      Auto-commit changes (default: true)
  CODING_AGENT_BRANCH_PREFIX    Git branch prefix (default: task/)
  CODING_AGENT_LOG              Log file path
  CODING_AGENT_CUSTOM_CMD       Command for 'custom' backend
  CODING_AGENT_DISCORD_WEBHOOK_URL            Discord webhook URL (optional)
  CODING_AGENT_DISCORD_NOTIFY_ON_BLOCKED      Notify when a task becomes blocked (default: true)
  CODING_AGENT_DISCORD_NOTIFY_ON_FAILED       Notify on failed verification (default: false)
  CODING_AGENT_DISCORD_NOTIFY_ON_DONE         Notify on task completion (default: false)
  GEMINI_API_KEY                Required for 'gemini' backend
  OPENAI_API_KEY                Required for 'codex' backend
HELP
            exit 0
            ;;
        *)  echo "Unknown option: $1"; exit 1 ;;
    esac
done

# ── Functions ───────────────────────────────────────────────────────

status_json_task_count() {
    # Prints the number of tasks in tasks/status.json. Errors if JSON is invalid.
    local status_json="${REPO_ROOT}/tasks/status.json"
    [[ -f "$status_json" ]] || return 1
    python3 -c "
import json
with open('$status_json', 'r', encoding='utf-8') as f:
    data = json.load(f)
tasks = data.get('tasks', [])
print(len(tasks) if isinstance(tasks, list) else 0)
"
}

ensure_bootstrap_task_plan() {
    # If a repo has only docs/, create a single bootstrap task that generates the full plan.
    # This enables dropping into a new repo with just docs/project.md + docs/guide.md.
    local status_json="${REPO_ROOT}/tasks/status.json"
    local bootstrap_task_id="00_generate_task_plan"
    local bootstrap_task_file="${REPO_ROOT}/tasks/${bootstrap_task_id}.md"

    if [[ -f "$status_json" ]]; then
        local count=""
        if ! count="$(status_json_task_count)"; then
            log_error "tasks/status.json exists but is not valid JSON; refusing to overwrite"
            return 1
        fi
        if [[ "$count" -gt 0 ]]; then
            return 0
        fi
    fi

    if [[ ! -f "${REPO_ROOT}/docs/project.md" ]]; then
        log_error "Missing docs/project.md; cannot bootstrap task plan"
        return 1
    fi

    mkdir -p "${REPO_ROOT}/tasks"

    if [[ ! -f "$bootstrap_task_file" ]]; then
        cat >"$bootstrap_task_file" <<'TASK'
# Task 00: Generate Task Plan From docs/project.md

## Goal

Generate a complete, verifiable task plan from `docs/project.md` so the coding agent can execute the project from scratch.

## Dependencies

None.

## Steps

1. Read `docs/project.md` and `docs/guide.md`.
2. Create a complete set of task files in `tasks/` following the task structure used in this repo.
3. Update `tasks/status.json` to include:
   - This task: `00_generate_task_plan` (keep it present)
   - All generated tasks with `status: "pending"`
   - Correct `depends_on` so tasks are runnable in a sane order
4. Constraints for generated tasks:
   - Small (1-4 hours), atomic, idempotent
   - Every task has Verification commands that fail if the task isn't done
   - Every task produces Outputs for downstream tasks (ports, container names, file paths, URLs)
   - Minimize manual steps; prefer scripts and `docker compose` workflows
   - Prefer internal-only service exposure; reverse proxy handles ingress
5. If `docs/project.md` is missing key details, add a task to clarify them instead of guessing.

## Expected Outcome

- `tasks/status.json` contains a full plan (multiple tasks).
- `tasks/NN_*.md` files exist for every task in `tasks/status.json`.
- The next runnable task after this one is a concrete "bootstrap" task (repo structure, compose skeleton, etc.).

## Verification

```bash
python3 -c 'import json; d=json.load(open("tasks/status.json")); assert len(d.get("tasks", [])) >= 2'
python3 -c 'import json, sys; d=json.load(open("tasks/status.json")); ids=[t["id"] for t in d["tasks"]]; assert "00_generate_task_plan" in ids'
python3 -c 'import json, pathlib; d=json.load(open("tasks/status.json")); ids=[t["id"] for t in d["tasks"]]; missing=[i for i in ids if not pathlib.Path("tasks", f"{i}.md").exists()]; assert not missing, f"missing task files: {missing}"'
```

## Outputs

- `generated`: true
TASK
    fi

    if [[ ! -f "$status_json" ]] || [[ "$(status_json_task_count 2>/dev/null || echo 0)" -eq 0 ]]; then
        cat >"$status_json" <<'JSON'
{
  "tasks": [
    {
      "id": "00_generate_task_plan",
      "status": "pending",
      "depends_on": [],
      "retries": 0,
      "max_retries": 3,
      "outputs": {},
      "error": null
    }
  ]
}
JSON
        log_info "Bootstrapped tasks/status.json with 00_generate_task_plan"
    fi
}

build_prompt() {
    local task_id="$1"
    local task_file
    task_file="$(get_task_file "$task_id")"

    if [[ "$task_id" == "00_generate_task_plan" ]]; then
        cat <<PROMPT
You are executing the bootstrap task "${task_id}".

Read docs/project.md and docs/guide.md.

Your job is to GENERATE the task plan (not to implement the platform yet):
- Create task files under tasks/ (tasks/NN_short_name.md).
- Update tasks/status.json to include this task id (00_generate_task_plan) AND all newly generated tasks.

Constraints for the generated plan:
- Tasks must be small (1-4 hours), atomic, and idempotent.
- Every task must include a \`\`\`bash\`\`\` Verification block that fails when the task isn't complete.
- Tasks must include Outputs that downstream tasks can consume (ports, container names, file paths, URLs).
- Minimize manual steps; prefer scripts and docker compose workflows.
- If docs/project.md is missing key details, add explicit clarification tasks (do not guess).

Important:
- You MAY modify tasks/status.json for this bootstrap task.
- You MAY create/edit tasks/*.md files.
- Do not run destructive commands.

Bootstrap task file contents:
---
$(cat "$task_file")
---
PROMPT
        return 0
    fi

    cat <<PROMPT
You are implementing task "${task_id}" for this project.

Read and follow the task file exactly: tasks/${task_id}.md

After implementing all steps, run the Verification commands from the task file.
If verification passes, the task is done.
If verification fails, fix the issue and retry.

Important:
- Make changes idempotent (safe to re-run).
- Only modify files within the project repository.
- Do not modify tasks/status.json -- the outer script handles that.
- Do not run destructive commands (rm -rf, etc.).
- Commit messages are handled by the outer script.

Task file contents:
---
$(cat "$task_file")
---
PROMPT
}

run_verification() {
    local task_id="$1"
    local task_file
    task_file="$(get_task_file "$task_id")"

    local commands
    commands="$(extract_verification "$task_file")" || {
        log_warn "No verification commands found for ${task_id}"
        return 0
    }

    # Force non-interactive mode for docker compose exec (idempotent)
    commands="${commands//docker compose exec -T /docker compose exec }"
    commands="${commands//docker compose exec /docker compose exec -T }"

    log_info "Running verification for ${task_id}"
    (
        cd "$REPO_ROOT"
        set -e
        eval "$commands" < /dev/null
    )
}

do_git_commit() {
    local task_id="$1"
    if [[ "$AUTO_COMMIT" != "true" ]]; then
        log_info "Auto-commit disabled, skipping git commit"
        return 0
    fi

    cd "$REPO_ROOT"

    git add -A
    if git diff --cached --quiet; then
        log_info "No changes to commit for ${task_id}"
        return 0
    fi

    git commit -m "$(cat <<EOF
task(${task_id}): implement task

Backend: ${BACKEND}
Automated commit by coding-agent.
EOF
)"
    log_info "Committed changes for ${task_id}"
}

do_status_commit() {
    local task_id="$1" status="$2"
    if [[ "$AUTO_COMMIT" != "true" ]]; then
        return 0
    fi

    cd "$REPO_ROOT"
    git add tasks/status.json
    if git diff --cached --quiet; then
        return 0
    fi

    git commit -m "task(${task_id}): mark ${status}"
}

handle_failure() {
    local task_id="$1"
    local error_msg="${2:-verification failed}"

    increment_retries "$task_id"
    local retries max_retries
    retries="$(get_task_retries "$task_id")"
    max_retries="$(get_task_max_retries "$task_id")"

    if [[ "$retries" -ge "$max_retries" ]]; then
        log_error "Task ${task_id} blocked after ${retries} retries"
        update_task_status "$task_id" "blocked" "$error_msg"
        do_status_commit "$task_id" "blocked"
        if [[ "$DISCORD_NOTIFY_ON_BLOCKED" == "true" ]]; then
            discord_post "ALERT: Task blocked: ${task_id}\nError: ${error_msg}\nRepo: ${REPO_ROOT}"
        fi
    else
        log_warn "Task ${task_id} failed (retry ${retries}/${max_retries}): ${error_msg}"
        update_task_status "$task_id" "failed" "$error_msg"
        do_status_commit "$task_id" "failed"
        if [[ "$DISCORD_NOTIFY_ON_FAILED" == "true" ]]; then
            discord_post "WARN: Task failed: ${task_id} (${retries}/${max_retries})\nError: ${error_msg}\nRepo: ${REPO_ROOT}"
        fi
    fi
}

run_task() {
    local task_id="$1"
    local task_file
    task_file="$(get_task_file "$task_id")"

    if [[ ! -f "$task_file" ]]; then
        log_error "Task file not found: ${task_file}"
        handle_failure "$task_id" "task file not found: ${task_file}"
        return 1
    fi

    # Check dependencies
    if ! check_dependencies "$task_id" > /dev/null 2>&1; then
        log_error "Unmet dependencies for ${task_id}"
        return 1
    fi

    log_info "=== Starting task: ${task_id} (backend: ${BACKEND}) ==="

    # Build the prompt
    local prompt
    prompt="$(build_prompt "$task_id")"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[dry-run] Would invoke backend: ${BACKEND}"
        log_info "[dry-run] Prompt length: ${#prompt} chars"
        log_info "[dry-run] Task file: ${task_file}"
        log_info "[dry-run] Timeout: ${TASK_TIMEOUT}"
        return 0
    fi

    # Mark in progress (only when actually running)
    update_task_status "$task_id" "in_progress"
    do_status_commit "$task_id" "in_progress"

    # Invoke the LLM backend
    log_info "Invoking backend '${BACKEND}' for task ${task_id}..."
    local agent_exit=0
    if [[ -n "$LOG_FILE" ]]; then
        mkdir -p "$(dirname "$LOG_FILE")"
        if ! echo "$prompt" | run_backend "$BACKEND" "$TASK_TIMEOUT" 2>&1 | tee -a "$LOG_FILE"; then
            agent_exit=1
        fi
    else
        if ! echo "$prompt" | run_backend "$BACKEND" "$TASK_TIMEOUT" 2>&1; then
            agent_exit=1
        fi
    fi

    if [[ "$agent_exit" -ne 0 ]]; then
        log_error "Backend '${BACKEND}' exited with error for ${task_id}"
        handle_failure "$task_id" "backend '${BACKEND}' exited with error"
        return 1
    fi

    # Run verification
    if run_verification "$task_id"; then
        log_info "Verification passed for ${task_id}"
        do_git_commit "$task_id"
        update_task_status "$task_id" "done"
        do_status_commit "$task_id" "done"
        if [[ "$DISCORD_NOTIFY_ON_DONE" == "true" ]]; then
            discord_post "OK: Task done: ${task_id}\nRepo: ${REPO_ROOT}"
        fi
        log_info "=== Task ${task_id} completed ==="
        return 0
    else
        log_error "Verification failed for ${task_id}"
        handle_failure "$task_id" "verification commands failed"
        return 1
    fi
}

# ── Main ────────────────────────────────────────────────────────────

main() {
    cd "$REPO_ROOT"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[dry-run] mode enabled, backend: ${BACKEND}"
    fi

    if [[ "$AUTO_BOOTSTRAP" == "true" ]]; then
        ensure_bootstrap_task_plan
    fi

    if [[ -n "$SPECIFIC_TASK" ]]; then
        run_task "$SPECIFIC_TASK"
        return $?
    fi

    while true; do
        local next_task
        next_task="$(get_next_task)"

        if [[ -z "$next_task" ]]; then
            log_info "No runnable tasks found"
            if [[ "$DRY_RUN" == "true" ]]; then
                echo "next_task: (none)"
            fi
            break
        fi

        if [[ "$DRY_RUN" == "true" ]]; then
            echo "next_task: ${next_task}"
            local all_runnable
            all_runnable="$(get_runnable_tasks)"
            echo "all_runnable:"
            echo "$all_runnable" | sed 's/^/  - /'
            break
        fi

        run_task "$next_task" || true

        if [[ "$LOOP" != "true" ]]; then
            break
        fi

        sleep 2
    done
}

main
