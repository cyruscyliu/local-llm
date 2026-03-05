# Task 02: Setup Docker Environment

## Goal

Ensure Docker and Docker Compose are available and the NVIDIA Container Toolkit is configured for GPU access.

## Dependencies

- `01_setup_repo`

## Steps

1. Verify Docker is installed and the daemon is running
2. Verify Docker Compose v2 is available (`docker compose version`)
3. Verify NVIDIA Container Toolkit is installed (`nvidia-ctk --version` or `docker run --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi`)
4. Create a test compose file that runs `nvidia-smi` inside a container to confirm GPU passthrough
5. Document the Docker and GPU driver versions in `infra/environment.md`

## Expected Outcome

- Docker daemon is running
- `docker compose` is available
- GPU passthrough works inside containers
- Versions documented

## Verification

```bash
docker info > /dev/null 2>&1
docker compose version > /dev/null 2>&1
docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi
```

## Outputs

- `docker_version`: output of `docker --version`
- `gpu_available`: true/false
