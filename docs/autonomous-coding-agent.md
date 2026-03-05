# Autonomous Coding Agent

This document describes the design for an autonomous coding agent that
builds and deploys the platform by working through task files without
human interaction.

This is a reusable pattern -- it can be applied to any project that
follows the task file structure described here.

------------------------------------------------------------------------

## 1. Task Structure

Tasks live in `tasks/` as individual markdown files. Each task is atomic
and contains:

-   **Goal** -- what the task accomplishes
-   **Steps** -- concrete implementation steps
-   **Dependencies** -- other tasks that must complete first
-   **Expected outcome** -- what success looks like
-   **Verification** -- commands to confirm the task is done
-   **Outputs** -- artifacts or values produced for downstream tasks

------------------------------------------------------------------------

## 2. Task Tracker

State is tracked in `tasks/status.json`:

```json
{
  "tasks": [
    {
      "id": "01_first_task",
      "status": "pending",
      "depends_on": [],
      "retries": 0,
      "max_retries": 3,
      "outputs": {},
      "error": null
    }
  ]
}
```

Valid statuses: `pending`, `in_progress`, `done`, `failed`, `blocked`.

------------------------------------------------------------------------

## 3. Agent Loop

The agent executes a continuous loop:

1.  Read `tasks/status.json`
2.  Select next task (all dependencies satisfied, status is `pending`)
3.  Set status to `in_progress`
4.  Read the corresponding task markdown file
5.  Implement the task
6.  Run verification commands
7.  If verification passes: set status to `done`, record outputs, commit
8.  If verification fails: increment retries, if retries >= max_retries
    set status to `blocked`, log error
9.  Repeat

------------------------------------------------------------------------

## 4. Dependency Graph

Tasks declare dependencies via `depends_on`. The agent only starts a
task when all dependencies have status `done`.

Independent tasks (no mutual dependencies) may run in parallel if the
agent supports it. For example, tasks that deploy independent services
can run concurrently if they share the same parent dependency.

------------------------------------------------------------------------

## 5. Inter-Task Communication

Tasks produce outputs (container names, ports, config paths) stored in
`status.json`. Downstream tasks read these outputs to configure
themselves.

Example: a database deployment task produces:

```json
{
  "container": "db",
  "port": 5432,
  "host": "db"
}
```

A downstream API gateway task reads these outputs to build its
database connection string.

------------------------------------------------------------------------

## 6. Idempotency Requirement

Every task must be safe to re-run. If the agent crashes mid-task and
restarts, re-executing the task must not cause failures.

Examples:

-   Use `docker compose up -d` (idempotent) instead of `docker create`
-   Use `CREATE TABLE IF NOT EXISTS` instead of `CREATE TABLE`
-   Check if a file exists before writing it
-   Use `--force-recreate` flags where appropriate

------------------------------------------------------------------------

## 7. Error Handling

-   Each task has a `max_retries` (default: 3)
-   On failure: increment retry counter, log the error in `status.json`
-   After max retries: mark as `blocked`, skip to the next independent
    task
-   Send alert (webhook/log file) when a task is blocked
-   Never loop forever on a broken task

------------------------------------------------------------------------

## 8. Safety Boundaries

The agent may only modify:

-   `docker/`
-   `infra/`
-   `configs/`
-   `scripts/`
-   `tasks/status.json`

The agent must never:

-   Run `rm -rf` or other destructive system commands
-   Modify files outside the allowed paths
-   Push to protected branches without verification passing

------------------------------------------------------------------------

## 9. Human Escalation

When a task is `blocked`, the agent logs a structured summary:

-   What it tried
-   What failed
-   Error messages
-   Number of retries exhausted

A human reviews blocked tasks and either:

-   Fixes the underlying issue and resets status to `pending`
-   Modifies the task definition
-   Removes the task

The agent continues working on non-blocked tasks while waiting.

------------------------------------------------------------------------

## 10. Git Workflow

The agent works on a branch per task (e.g., `task/03_deploy_postgres`).
After verification passes, the branch is merged to the main branch.

This prevents broken intermediate state from reaching main. If a task
fails, only its branch is affected.

------------------------------------------------------------------------

## 11. Running the Agent

The agent can run as:

-   A manual invocation on a development machine
-   A cron job or systemd timer for scheduled work
-   A long-running service that polls for new tasks

Example cron entry for nightly runs:

```
0 22 * * * cd /path/to/repo && ./run-agent.sh >> /var/log/agent.log 2>&1
```

The agent should have a hard timeout to prevent runaway execution.
