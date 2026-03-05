---
# Task 13: Setup NVIDIA GPU Exporter

## Goal

Deploy NVIDIA GPU Exporter to collect GPU-specific metrics for monitoring.

## Dependencies

- 10_setup_prometheus

## Steps

1. Add an `nvidia-gpu-exporter` service definition to `docker-compose.yml`.
2. Configure GPU access for the container.
3. Configure Prometheus to scrape metrics from the `nvidia-gpu-exporter` service by updating `data/prometheus/prometheus.yml`.
4. Expose port `9400` internally within the Docker network.
5. Add a health check to the service.

## Expected Outcome

The NVIDIA GPU Exporter container is running, healthy, and Prometheus is successfully scraping its metrics.

## Verification

```bash
docker compose up -d nvidia-gpu-exporter
docker compose ps -q nvidia-gpu-exporter | xargs docker inspect --format '{{.State.Health.Status}}' | grep -q "healthy"
curl -f http://localhost:9400/metrics # Check if NVIDIA GPU Exporter metrics are accessible
# Verify Prometheus is scraping: check Prometheus UI -> Status -> Targets
```

## Outputs

- `nvidia_gpu_exporter_container_name`: `nvidia-gpu-exporter`
- `nvidia_gpu_exporter_port`: `9400`
---