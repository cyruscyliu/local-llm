# Agent Instructions

This file tells an AI coding agent how to work in this repository.

## Project Context

Read `docs/project.md` for what this project is.
Read `docs/guide.md` for how the task system works.

## Your Job

1. Read `tasks/status.json` to find the next runnable task.
2. A task is runnable when its status is `pending` and all `depends_on` tasks are `done`.
3. Read the task file (`tasks/<id>.md`) and follow its Steps exactly.
4. Run the Verification commands from the task file.
5. If verification passes, the task is done.
6. If verification fails, fix the issue and retry.

## Rules

- Make all changes idempotent (safe to re-run if interrupted).
- Only modify files within this repository.
- Do not modify `tasks/status.json` -- the outer agent script handles status tracking.
- Do not run destructive commands (`rm -rf /`, `docker system prune -af`, etc.).
- Do not push to remote repositories.
- Do not commit -- the outer script handles git commits.
- Stay within allowed paths: `docker/`, `infra/`, `configs/`, `scripts/`, `data/`, `models/`.
- Prefer `docker compose` for service management.
- Prefer `set -e` style commands that fail loudly on error.

## Task File Format

Each task in `tasks/` has:
- **Goal**: what the task accomplishes
- **Dependencies**: tasks that must be done first
- **Steps**: what to implement
- **Expected Outcome**: what success looks like
- **Verification**: commands to prove it works
- **Outputs**: values for downstream tasks (ports, names, paths)

## When You're Stuck

- Re-read the task file carefully.
- Check the outputs of dependency tasks in `tasks/status.json`.
- If a dependency output is missing, check what that task produced.
- Do not skip verification steps.
