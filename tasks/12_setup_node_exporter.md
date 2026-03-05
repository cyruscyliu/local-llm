---
# Task 12: Setup Node Exporter

## Goal

Deploy Node Exporter to collect host-level metrics for monitoring.

## Dependencies

- 10_setup_prometheus

## Steps

1. Add a `node-exporter` service definition to `docker-compose.yml`.
2. Configure Prometheus to scrape metrics from the `node-exporter` service by updating `data/prometheus/prometheus.yml`.
3. Expose port `9100` internally within the Docker network.
4. Add a health check to the service.

## Expected Outcome

The Node Exporter container is running, healthy, and Prometheus is successfully scraping its metrics.

## Verification

```bash
docker-compose up -d node-exporter
docker-compose ps -q node-exporter | xargs docker inspect --format '{{.State.Health.Status}}' | grep -q "healthy"
curl -f http://localhost:9100/metrics # Check if Node Exporter metrics are accessible
# Verify Prometheus is scraping: check Prometheus UI -> Status -> Targets
```

## Outputs

- `node_exporter_container_name`: `node-exporter`
- `node_exporter_port`: `9100`
---