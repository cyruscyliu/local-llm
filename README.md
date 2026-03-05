# Local LLM Platform

## Install dependencies

```bash
sudo apt-get update
sudo apt-get install -y \
  ca-certificates \
  coreutils \
  curl \
  docker-compose-plugin \
  docker.io \
  git \
  jq \
  make \
  nodejs \
  python3 \
  python3-pip
```

## Configure

Agent config lives in `configs/coding-agent.yaml`. Most secrets should be
provided via environment variables.

Examples:

```bash
# Choose an LLM backend
export CODING_AGENT_BACKEND=gemini
export GEMINI_API_KEY=...

# Create a discord webhook
export CODING_AGENT_DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/..."
```

## Vibe coding and execution

```bash
./scripts/coding-agent.sh --dry-run
./scripts/coding-agent-wrapper.sh --loop
```

When `tasks/status.json` is missing/empty, the agent creates and runs
`tasks/00_generate_task_plan.md`, which generates:

- `tasks/status.json` (full dependency graph)
- `tasks/NN_*.md` task files

## Common Commands

```bash
make task-summary
make task-runnable
make task-next
```

## License

TBD.
