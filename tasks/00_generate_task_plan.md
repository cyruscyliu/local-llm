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
   - Minimize manual steps; prefer scripts and `docker-compose` workflows
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
