# Task 14: Build Autonomous Coding Agent

## Goal

Create the coding agent that reads task files and executes them autonomously,
following the design in `docs/guide.md` (Coding Agent section).

## Dependencies

- `01_setup_repo`

## Steps

1. Create the agent runner script at `scripts/coding-agent.sh`
   - Parse `tasks/status.json` to find the next pending task
   - Check that all `depends_on` tasks have status `done`
   - Set the selected task to `in_progress`
   - Read the task markdown file and extract steps and verification commands
   - Execute the task (invoke the coding agent CLI with the task as context)
   - Run verification commands
   - On success: update status to `done`, record outputs, git commit
   - On failure: increment retries, log error, mark `blocked` if max retries hit
   - Loop to the next task
2. Create a helper library at `scripts/lib/task_utils.sh` with functions:
   - `get_next_task` -- find next runnable task from status.json
   - `update_task_status` -- update a task's status in status.json
   - `record_outputs` -- write outputs to status.json
   - `get_task_outputs` -- read outputs from a dependency
   - `check_dependencies` -- verify all deps are done
3. Create a configuration file at `configs/coding-agent.yaml`
   - `allowed_paths`: list of directories the agent may modify
   - `max_retries`: default retry limit
   - `timeout_minutes`: per-task timeout
   - `git_branch_prefix`: "task/"
   - `auto_commit`: true/false
4. Create `scripts/coding-agent-wrapper.sh` for cron/systemd use
   - Set up logging to `data/coding-agent/agent.log`
   - Hard timeout for the entire run
   - Lock file to prevent concurrent runs
5. Add a CLAUDE.md (or agent instructions file) at project root
   - Instruct the agent to read `tasks/status.json`
   - Instruct it to follow the task file format
   - Define safety boundaries and allowed paths
   - Reference `docs/guide.md` for full design

## Expected Outcome

- Agent can pick up the next pending task and execute it
- Status.json is updated after each task
- Git commits are created per completed task
- Failed tasks are retried up to the limit, then blocked
- Concurrent runs are prevented via lock file

## Verification

```bash
test -f scripts/coding-agent.sh && test -x scripts/coding-agent.sh
test -f scripts/lib/task_utils.sh
test -f configs/coding-agent.yaml
# Dry run: agent should identify the first pending task
bash scripts/coding-agent.sh --dry-run | grep -q "next_task"
```

## Outputs

- `agent_script`: "scripts/coding-agent.sh"
- `agent_config`: "configs/coding-agent.yaml"
- `agent_log`: "data/coding-agent/agent.log"
