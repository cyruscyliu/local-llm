# Task 06: Deploy vLLM

## Goal

Deploy the vLLM inference server with GPU access, serving an OpenAI-compatible API.

## Dependencies

- `02_setup_docker`

## Steps

1. Add vLLM service to `docker/docker-compose.yml`
   - Image: `vllm/vllm-openai:latest`
   - Port: 8000 (internal only)
   - GPU access: deploy with `runtime: nvidia` or `device_requests`
   - Volume: `models/` mounted for model files
   - Environment variables from `.env`:
     - `VLLM_MODEL` -- model path or HuggingFace ID
     - `VLLM_GPU_MEMORY_UTILIZATION` -- default 0.9
     - `VLLM_MAX_MODEL_LEN` -- default 8192
   - Health check: `curl -f http://localhost:8000/health`
   - Restart policy: `unless-stopped`
   - Network: `llm-platform`
2. Create vLLM config at `configs/vllm_config.yaml` if needed
3. Add vLLM variables to `.env.example`

## Expected Outcome

- vLLM container starts with GPU access
- Model is loaded and serving requests
- OpenAI-compatible API is available at port 8000

## Verification

```bash
docker compose -f docker/docker-compose.yml ps vllm
docker compose -f docker/docker-compose.yml exec vllm curl -sf http://localhost:8000/health
docker compose -f docker/docker-compose.yml exec vllm curl -sf http://localhost:8000/v1/models
```

## Outputs

- `container`: "vllm"
- `port`: 8000
- `host`: "vllm"
- `api_base`: "http://vllm:8000/v1"
