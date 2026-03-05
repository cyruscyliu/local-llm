# Task 07: Deploy LiteLLM

## Goal

Deploy LiteLLM as the API gateway, routing requests to vLLM and managing API keys and rate limits.

## Dependencies

- `03_deploy_postgres`
- `04_deploy_redis`
- `06_deploy_vllm`

## Steps

1. Create LiteLLM config at `configs/litellm.yaml`
   - Define model list pointing to vLLM backend (`http://vllm:8000/v1`)
   - Configure PostgreSQL as the database for API key storage
   - Configure Redis for caching and rate limiting
2. Add LiteLLM service to `docker/docker-compose.yml`
   - Image: `ghcr.io/berriai/litellm:main-latest`
   - Port: 4000 (internal only)
   - Volume mount: `configs/litellm.yaml`
   - Environment from `.env`: database URL, Redis URL, master key
   - Health check: `curl -f http://localhost:4000/health`
   - Restart policy: `unless-stopped`
   - Network: `llm-platform`
   - Depends on: postgres, redis, vllm
3. Add LiteLLM variables to `.env.example`

## Expected Outcome

- LiteLLM starts and connects to PostgreSQL, Redis, and vLLM
- API gateway is accessible at port 4000
- Requests are routed to vLLM backend

## Verification

```bash
docker compose -f docker/docker-compose.yml ps litellm
docker compose -f docker/docker-compose.yml exec litellm curl -sf http://localhost:4000/health
```

## Outputs

- `container`: "litellm"
- `port`: 4000
- `host`: "litellm"
- `api_base`: "http://litellm:4000"
