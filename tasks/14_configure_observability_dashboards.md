---
# Task 14: Configure Observability Dashboards

## Goal

Configure Grafana dashboards to display key metrics for GPU utilization, VRAM usage, request latency, token throughput, queue size, and active users.

## Dependencies

- 11_setup_grafana
- 12_setup_node_exporter
- 13_setup_nvidia_gpu_exporter

## Steps

1. Create Grafana provisioning files in `configs/grafana/dashboards/` to define and import dashboards.
2. Dashboards should cover:
   - GPU utilization and VRAM usage (from NVIDIA GPU Exporter).
   - Host-level metrics like CPU, memory, disk (from Node Exporter).
   - Request latency, token throughput, queue size (from LiteLLM/vLLM, assuming they expose Prometheus metrics or can be derived).
3. Restart Grafana to apply the new dashboard configurations.

## Expected Outcome

Grafana displays comprehensive dashboards with data from all configured exporters and services.

## Verification

```bash
# This verification is more complex as it requires interacting with Grafana's API or UI.
# A simple check could be to ensure the provisioning files are correctly loaded.
docker compose exec grafana ls /etc/grafana/provisioning/dashboards/
# Manual verification: Access Grafana UI (http://localhost:3001) and confirm dashboards are present and populated.
```

## Outputs

None (dashboards are internal to Grafana).
---