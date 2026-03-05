---
# Task 06: Deploy vLLM

## Goal

Deploy the vLLM service using Docker Compose to provide GPU-accelerated LLM inference.

## Dependencies

- 02_create_docker_compose_skeleton

## Steps

1. Add a `vllm` service definition to `docker-compose.yml`.
2. Configure GPU access for the container (e.g., `deploy.resources.reservations.devices`).
3. Mount the `models/` directory into the container.
4. Set the command to run the vLLM API server with a placeholder model path (e.g., `/models/placeholder-model`).
5. Expose port `8000` internally within the Docker network.
6. Add a health check to the service.

## Expected Outcome

The vLLM container is running and attempting to start the API server. It might show errors about a missing model, which will be addressed in a later task.

## Verification

```bash
docker-compose up -d vllm
docker-compose ps -q vllm | xargs docker inspect --format '{{.State.Health.Status}}' | grep -q "healthy"
# Note: Initial health check might pass even if model loading fails.
# A more robust check will be added after a model is provided.
```

## Outputs

- `vllm_container_name`: `vllm`
- `vllm_port`: `8000`
---