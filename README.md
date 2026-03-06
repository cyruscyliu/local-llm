# Local LLM Platform

## Goal

Run a local LLM platform for internal multi-user chat and OpenAI-compatible API access.

## Current Setup

- OS: Debian 12
- GPU: NVIDIA RTX 4090
- Runtime: Docker + Docker Compose

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
  python3
```

## Configure

Create your environment file and update secrets/keys:

```bash
cp .env.example .env
# Then edit .env with your real values.
```

## DevOps Workflow

1. Start the full stack:

```bash
./scripts/start.sh
```

2. Check runtime health:

```bash
./scripts/health.sh
```

3. Validate configuration:

```bash
./scripts/check-config.sh
```

4. Pull latest code and restart impacted services:

```bash
./scripts/restart.sh
```

## License

Apache License 2.0. See [LICENSE](LICENSE).
