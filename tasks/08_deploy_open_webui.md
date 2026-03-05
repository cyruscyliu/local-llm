---
# Task 08: Deploy Open WebUI

## Goal

Deploy the Open WebUI chat portal service using Docker Compose, configured to use LiteLLM as its backend.

## Dependencies

- 07_deploy_litellm

## Steps

1. Add an `open-webui` service definition to `docker-compose.yml`.
2. Configure environment variables or settings to point Open WebUI to the LiteLLM service (e.g., `OLLAMA_API_BASE_URL`).
3. Expose port `3000` internally within the Docker network.
4. Add a health check to the service.

## Expected Outcome

The Open WebUI container is running, healthy, and can connect to LiteLLM.

## Verification

```bash
docker-compose up -d open-webui
docker-compose ps -q open-webui | xargs docker inspect --format '{{.State.Health.Status}}' | grep -q "healthy"
curl -f http://localhost:3000 # Assuming internal exposure allows localhost access from host or another container
```

## Outputs

- `open_webui_container_name`: `open-webui`
- `open_webui_port`: `3000`
---