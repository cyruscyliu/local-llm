---
# Task 07: Deploy LiteLLM

## Goal

Deploy the LiteLLM API Gateway service using Docker Compose, configuring it to connect to its dependencies.

## Dependencies

- 03_deploy_postgres
- 04_deploy_redis
- 06_deploy_vllm

## Steps

1. Add a `litellm` service definition to `docker-compose.yml`.
2. Create `configs/litellm.yaml` with basic configuration, including connections to PostgreSQL, Redis, and vLLM.
3. Mount the `configs/litellm.yaml` into the container.
4. Expose port `4000` internally within the Docker network.
5. Add a health check to the service.

## Expected Outcome

The LiteLLM container is running, healthy, and can connect to PostgreSQL, Redis, and vLLM.

## Verification

```bash
docker compose up -d litellm
docker compose ps -q litellm | xargs docker inspect --format '{{.State.Health.Status}}' | grep -q "healthy"
curl -f http://localhost:4000/health # Assuming internal exposure allows localhost access from host or another container
```

## Outputs

- `litellm_container_name`: `litellm`
- `litellm_port`: `4000`
---