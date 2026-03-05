# Task 10: Setup Monitoring (Prometheus)

## Goal

Deploy Prometheus with exporters to collect metrics from all services and the GPU.

## Dependencies

- `06_deploy_vllm`
- `07_deploy_litellm`

## Steps

1. Create Prometheus config at `configs/prometheus/prometheus.yml`
   - Scrape targets: vLLM, LiteLLM, node exporter, NVIDIA GPU exporter
   - Scrape interval: 15s
   - Retention: 15d
2. Add Prometheus service to `docker/docker-compose.yml`
   - Image: `prom/prometheus:latest`
   - Port: 9090 (internal only)
   - Volume: `configs/prometheus/prometheus.yml`, `data/prometheus`
   - Restart policy: `unless-stopped`
   - Network: `llm-platform`
3. Add Node exporter service
   - Image: `prom/node-exporter:latest`
   - Port: 9100 (internal only)
   - Network: `llm-platform`
4. Add NVIDIA GPU exporter service
   - Image: `utkuozdemir/nvidia_gpu_exporter:latest`
   - Port: 9835 (internal only)
   - GPU access required
   - Network: `llm-platform`

## Expected Outcome

- Prometheus scrapes all targets
- GPU metrics (utilization, VRAM, temperature) are collected
- System metrics (CPU, memory, disk) are collected
- Service metrics (latency, throughput, errors) are collected

## Verification

```bash
docker compose -f docker/docker-compose.yml ps prometheus
docker compose -f docker/docker-compose.yml exec prometheus curl -sf http://localhost:9090/-/healthy
docker compose -f docker/docker-compose.yml exec prometheus curl -sf 'http://localhost:9090/api/v1/targets' | grep -q '"health":"up"'
```

## Outputs

- `container`: "prometheus"
- `port`: 9090
- `host`: "prometheus"
