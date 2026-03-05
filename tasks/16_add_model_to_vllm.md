---
# Task 16: Add Model to vLLM

## Goal

Download and configure a specific LLM model for the vLLM service to enable inference.

## Dependencies

- 06_deploy_vllm

## Steps

1. **Clarification Needed**: The `docs/project.md` mentions `/models/your-9b-model` as an example. A concrete model name and download instructions are required. For this task, we will assume a model named `TheBloke/Mistral-7B-Instruct-v0.2-GGUF` is to be used.
2. Download the specified LLM model into the `models/` directory.
3. Update the `vllm` service definition in `docker-compose.yml` (or `configs/vllm_config.yaml` if created) to point to the downloaded model file or directory.
4. Restart the `vllm` service to load the new model.

## Expected Outcome

The vLLM service successfully loads the specified model and is ready to serve inference requests.

## Verification

```bash
docker compose up -d vllm
docker compose logs vllm | grep "Loaded model"
curl -f http://localhost:8000/v1/models # Should list the loaded model
```

## Outputs

- `vllm_model_name`: `TheBloke/Mistral-7B-Instruct-v0.2-GGUF` (example)
---