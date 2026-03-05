# Project Guide

This repo is organized around two ideas:

1. `docs/project.md` is the **single source of truth** for what we are building.
2. `tasks/` is the **execution plan**: small, verifiable tasks tracked in `tasks/status.json`.

If you adopt this structure in another repo, you get a development workflow that is:
human-friendly, agent-friendly, and resilient to context loss.

---

## Start Here (5 Minutes)

1. Read `docs/project.md` end-to-end. If it’s out of date, fix that first.
2. Open `tasks/status.json` to see the roadmap and what’s runnable next.
3. Pick the next `pending` task whose dependencies are `done`.
4. Implement it (manually or via an agent), run the task’s verification commands, then mark it `done`.

Tip: this repo starts as “docs + tasks”. Directories like `docker/`, `configs/`, `scripts/`, etc. are created by early tasks (e.g. `tasks/01_setup_repo.md`).

---

## Repo Layout (Planned / Target)

This is the target structure the task plan converges to:

```text
docs/
  project.md                       # single source of truth: what the system is
  guide.md                         # this file: how to work in the repo
  autonomous-coding-agent.md       # reusable pattern: coding agent
  autonomous-maintenance-agent.md  # reusable pattern: maintenance agent

tasks/
  status.json                      # task state tracker
  NN_short_name.md                 # one task per file

docker/                            # compose files, Dockerfiles
infra/                             # host setup, systemd, cron, etc.
configs/                           # service configuration files
scripts/                           # operator / maintenance scripts (agent-callable)
data/                              # persistent volumes (usually gitignored)
models/                            # model storage (usually gitignored)
README.md                          # entry point for new users (created by tasks)
SECURITY.md                        # vulnerability reporting + threat model (created by tasks)
.env.example                       # documented env vars (created by tasks)
Makefile                           # shortcuts for task workflows (optional)
```

If reality and this diagram disagree, update this guide and/or add a task to make them converge.

---

## How Tasks Work

Each task is a Markdown file in `tasks/` with a fixed shape:

- **Goal**: what changes in the world when the task is done
- **Dependencies**: task `id`s that must be `done` first
- **Steps**: concrete implementation steps (commands, files, settings)
- **Expected Outcome**: what should exist / be true afterwards
- **Verification**: copy/paste commands that prove it
- **Outputs**: values or artifacts used by downstream tasks

Task state is tracked in `tasks/status.json`. A coding agent can read this file to decide what to do next (see `docs/autonomous-coding-agent.md`).

---

## The `status.json` Contract

Each entry in `tasks/status.json` follows this schema:

```json
{
  "id": "NN_short_name",
  "status": "pending",
  "depends_on": ["id_of_dependency"],
  "retries": 0,
  "max_retries": 3,
  "outputs": {},
  "error": null
}
```

Guidelines:

- `id` must match the filename suffix (e.g. `tasks/03_deploy_postgres.md` → `03_deploy_postgres`).
- `depends_on` should be minimal: depend on prerequisites, not “related work”.
- `outputs` should contain *stable* keys downstream tasks can reference (ports, container names, file paths, URLs).
- `error` is for a short, actionable message (what failed + where).

Task statuses:

| Status        | Meaning                                              |
|---------------|------------------------------------------------------|
| `pending`     | Not started (or reset)                               |
| `in_progress` | Actively being worked on                             |
| `done`        | Verified and complete                                |
| `failed`      | Verification failed; will be retried                 |
| `blocked`     | Retries exhausted; requires a human decision / fix   |

---

## Writing Great Tasks (So Humans *and* Agents Succeed)

If you want this project to feel “popular”, the task quality bar matters more than the tooling.

**A good task is:**

- Atomic: one coherent change with one verification story
- Idempotent: safe to re-run after partial completion
- Explicit: no “configure X” without naming file paths and exact settings
- Verifiable: verification commands fail when the task isn’t done
- Mergeable: leaves the repo in a consistent state after it lands

**Avoid:**

- Hidden prerequisites (“install some dependency”, “make sure Docker works”)
- Long multi-hour tasks (split them)
- “Verification” that’s just “open the UI and check”

**Verification checklist:**

- Use `set -e`-style commands that fail on error (`test`, `grep -q`, `curl -fsS`, etc.)
- Prefer checking externally observable behavior (health endpoints, ports open, container running)
- Keep it fast (minutes, not hours)

---

## Changing the Project (The Docs-First Rule)

`docs/project.md` is the “what”. Tasks are the “how”.

Update `docs/project.md` when:

- Architecture changes (service added/removed, routing, storage, auth)
- Capacity assumptions change (hardware, users, performance targets)
- Non-functional goals change (security posture, observability baseline)

Then create/update tasks so the repo can actually reach the new design.

Do **not** create `project_v2.md` or `project_2026.md`. Keep one file updated in place; Git history is your timeline.

---

## Adding / Modifying / Removing Tasks

### Add a new task

1. Update `docs/project.md` if the “what” changed.
2. Create `tasks/NN_short_name.md` using the structure in existing tasks.
3. Add an entry to `tasks/status.json` with `status: "pending"` and correct `depends_on`.

### Modify an existing task

- Edit the task file directly.
- If a task is `blocked` or `failed` and you fixed the issue, reset it in `tasks/status.json`:

  ```json
  {
    "status": "pending",
    "retries": 0,
    "error": null
  }
  ```

- Don’t silently change the meaning of a `done` task without also updating/reverting its implementation.

### Remove a task

1. Delete the task markdown file.
2. Remove the entry from `tasks/status.json`.
3. Remove it from any other task’s `depends_on`.

---

## Quick Reference (Working With `status.json`)

If you want minimal manual effort, use:

```bash
make task-summary
make task-runnable
make task-next
```

Or call the helper directly:

```bash
./scripts/tasks.py summary
./scripts/tasks.py runnable
./scripts/tasks.py next
```

Raw `jq` one-liners (no helper required):

```bash
# List runnable tasks: pending with all deps done
jq -r '
  def done($id): any(.tasks[]; .id == $id and .status == "done");
  .tasks[]
  | select(.status == "pending")
  | select(all(.depends_on[]; done(.)))
  | .id
' tasks/status.json

# Show blocked tasks with their last error
jq -r '.tasks[] | select(.status == "blocked") | "\(.id)\t\(.error)"' tasks/status.json

# Reset a task to pending
jq '(.tasks[] | select(.id == "TASK_ID")) |= (.status = "pending" | .retries = 0 | .error = null)' \
  tasks/status.json > tasks/status.json.tmp && mv tasks/status.json.tmp tasks/status.json

# Show dependencies for a task
jq -r '.tasks[] | select(.id == "TASK_ID") | .depends_on[]?' tasks/status.json
```

---

## Example Agent Prompts

These prompts are designed to work well for both local agents and hosted agents.

### Start autonomous execution

```
Read docs/project.md and docs/autonomous-coding-agent.md.
Read tasks/status.json.

Pick the next task with status "pending" where all dependencies are status "done".
Set it to "in_progress".

Implement the task by following tasks/<id>.md exactly.
Run the task's "Verification" commands.

If verification passes:
- update tasks/status.json to mark the task "done"
- record any relevant Outputs into the task's "outputs"
- commit the changes

If verification fails:
- increment retries
- write a short error into "error"
- if retries >= max_retries, mark it "blocked"
```

### Work on a specific task

```
Implement tasks/NN_short_name.md.
Follow the Steps exactly and keep changes minimal.
Run the Verification commands and paste/summarize the results.
If they pass, mark NN_short_name as "done" in tasks/status.json and record Outputs.
Commit.
```

### Add a new capability

```
I want to add: [describe the capability].

1) Update docs/project.md to reflect the new architecture/behavior.
2) Create one or more tasks in tasks/ with clear verification steps.
3) Add them to tasks/status.json with correct depends_on.
```

### Generate tasks from `docs/project.md`

Use this when you have a solid `docs/project.md` but the task plan is missing or low quality.

```
Read docs/project.md.

Generate a complete set of tasks to implement the platform described there.
Constraints:
- Tasks must be small (1-4 hours each), atomic, and idempotent.
- Every task must include Verification commands that fail if the task isn't done.
- Tasks must produce Outputs that downstream tasks can consume (ports, container names, file paths, URLs).
- Minimize manual steps; prefer scripts and `docker compose` workflows.

Deliverables:
1) A proposed ordered task list (id, short name, goal, dependencies).
2) Create tasks/NN_short_name.md for each task using this repo's task structure.
3) Update tasks/status.json to include all tasks with correct depends_on and status "pending".
4) Call out any assumptions or missing details in docs/project.md that block task generation.
```

---

## Adapting This System to Another Repo

If you want to reuse this approach in a different project:

1. Rewrite `docs/project.md` so it accurately describes the target system and constraints.
2. Create an initial “bootstrap” task (repo structure, linting, CI, env files).
3. Keep tasks small and verifiable; treat `tasks/status.json` as the roadmap.
4. Only add automation/agents after the human workflow feels solid.

### Fix a blocked task

```
Task NN_task_name is blocked. Read the error in tasks/status.json
and the task file tasks/NN_task_name.md.
Diagnose the issue, fix it, reset the task status to pending with
retries at 0, and re-run it.
```

### Resume after a crash

```
Read tasks/status.json. If any task is in_progress, check whether
its verification commands pass. If they do, mark it done and move on.
If not, reset it to pending and retry. Then continue with the next
pending task.
```

### Review progress

```
Read tasks/status.json and summarize:
- How many tasks are done, pending, blocked
- What the next runnable tasks are
- Any errors or blocked tasks that need attention
```

### Scale the platform

```
I want to add [new hardware or capacity].
Update docs/project.md with the change.
Create a task file with the implementation steps.
Add it to tasks/status.json with the correct dependencies.
```
