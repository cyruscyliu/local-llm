---
# Task 11: Setup Grafana

## Goal

Deploy Grafana for visualizing metrics collected by Prometheus.

## Dependencies

- 10_setup_prometheus

## Steps

1. Add a `grafana` service definition to `docker-compose.yml`.
2. Configure Grafana to use Prometheus as a data source. This might involve creating a provisioning file in `configs/grafana/datasources.yml`.
3. Configure persistent storage for Grafana in `data/grafana`.
4. Expose port `3001` internally within the Docker network (or a different port if `3000` is used by Open WebUI).
5. Add a health check to the service.

## Expected Outcome

The Grafana container is running, healthy, and accessible, with Prometheus configured as a data source.

## Verification

```bash
docker compose up -d grafana
docker compose ps -q grafana | xargs docker inspect --format '{{.State.Health.Status}}' | grep -q "healthy"
curl -f http://localhost:3001/login # Check if Grafana login page is accessible
```

## Outputs

- `grafana_container_name`: `grafana`
- `grafana_port`: `3001`
---