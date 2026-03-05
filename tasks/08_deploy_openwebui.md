# Task 08: Deploy Open WebUI

## Goal

Deploy Open WebUI as the chat web portal, connected to LiteLLM as its OpenAI-compatible backend.

## Dependencies

- `07_deploy_litellm`

## Steps

1. Add Open WebUI service to `docker/docker-compose.yml`
   - Image: `ghcr.io/open-webui/open-webui:main`
   - Port: 8080 (internal only; do not expose to host, reverse proxy will handle ingress)
   - Volume: `data/openwebui` for persistence
   - Environment from `.env`:
     - `OPENAI_API_BASE_URL` -- point to LiteLLM (`http://litellm:4000/v1`)
     - `WEBUI_SECRET_KEY`
   - Health check: `curl -fsS http://localhost:8080/` (use a simple HTTP 200 check)
   - Restart policy: `unless-stopped`
   - Network: `llm-platform`
   - Depends on: litellm
2. Add Open WebUI variables to `.env.example`

## Expected Outcome

- Open WebUI starts and connects to LiteLLM
- Chat interface is reachable behind the reverse proxy once configured
- Users can register, log in, and chat

## Verification

```bash
docker compose -f docker/docker-compose.yml ps openwebui
docker compose -f docker/docker-compose.yml exec openwebui curl -fsS http://localhost:8080/ > /dev/null
```

## Outputs

- `container`: "openwebui"
- `port`: 8080
- `host`: "openwebui"
