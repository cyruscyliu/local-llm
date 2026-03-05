---
# Task 13: Setup NVIDIA GPU Exporter

## Goal

Deploy the NVIDIA DCGM Exporter to collect GPU-specific metrics for monitoring.

## Dependencies

- 10_setup_prometheus

## Steps

1. Add a `dcgm-exporter` service definition to `docker-compose.yml` using the Docker Hub image `nvidia/dcgm-exporter`.
2. Configure GPU access for the container.
3. Configure Prometheus to scrape metrics from the `dcgm-exporter` service by updating `data/prometheus/prometheus.yml`.
4. Expose port `9400` internally within the Docker network.
5. Add a health check to the service.

## Expected Outcome

The NVIDIA DCGM Exporter container is running, healthy, and Prometheus is successfully scraping its metrics.

## Verification

```bash
docker-compose up -d dcgm-exporter
docker-compose ps -q dcgm-exporter | xargs docker inspect --format '{{.State.Health.Status}}' | grep -q "healthy"
curl -f http://localhost:9400/metrics # Check if DCGM Exporter metrics are accessible
# Verify Prometheus is scraping: check Prometheus UI -> Status -> Targets
```

## Outputs

- `nvidia_gpu_exporter_container_name`: `dcgm-exporter`
- `nvidia_gpu_exporter_port`: `9400`
---
