# Local LLM Platform

## Install dependencies

```bash
sudo apt-get update
sudo apt-get install -y \
  ca-certificates \
  coreutils \
  curl \
  docker-compose \
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

## HTTPS (Internal CA)

This deployment uses a private CA for internal/VPN-only HTTPS. Users must trust
the CA once to avoid browser warnings. Distribute `certs/ca.crt` and have users
install it on their devices:

Windows:

1. Double-click `ca.crt`.
2. Click "Install Certificate".
3. Choose "Local Machine" if prompted.
4. Place in "Trusted Root Certification Authorities".
5. Finish and restart the browser.

macOS:

1. Double-click `ca.crt` (opens Keychain Access).
2. Add to the System keychain.
3. Open the cert, set Trust to "Always Trust".
4. Close and enter admin password.

Ubuntu/Debian:

```bash
sudo cp ca.crt /usr/local/share/ca-certificates/local-llm-ca.crt
sudo update-ca-certificates
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
