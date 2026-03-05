# Task 12: Setup Grafana Dashboards

## Goal

Deploy Grafana with pre-configured dashboards for GPU, service, and system metrics.

## Dependencies

- `10_setup_monitoring`

## Steps

1. Add Grafana service to `docker/docker-compose.yml`
   - Image: `grafana/grafana:latest`
   - Port: 3000 (internal; optionally expose to host if you want direct access)
   - Volume: `data/grafana` for persistence
   - Environment from `.env`: admin user, admin password
   - Restart policy: `unless-stopped`
   - Network: `llm-platform`
2. Create provisioning configs at `configs/grafana/`
   - `datasources/prometheus.yml` -- auto-configure Prometheus datasource
   - `datasources/loki.yml` -- auto-configure Loki datasource (if deployed)
3. Create dashboard JSON files at `configs/grafana/dashboards/`
   - GPU dashboard: utilization, VRAM, temperature
   - Service dashboard: request latency, throughput, error rate, queue size
   - System dashboard: CPU, memory, disk, network
4. Configure alert rules:
   - GPU memory > 90%
   - Queue length > 20
   - Error rate > 5%
5. Add Grafana variables to `.env.example`

## Expected Outcome

- Grafana starts with Prometheus pre-configured as datasource
- Dashboards are auto-provisioned on startup
- Alerts fire when thresholds are exceeded

## Verification

```bash
docker compose -f docker/docker-compose.yml ps grafana
docker compose -f docker/docker-compose.yml exec grafana curl -sf http://localhost:3000/api/health
```

## Outputs

- `container`: "grafana"
- `port`: 3000
- `host`: "grafana"
