---
# Task 10: Setup Prometheus

## Goal

Deploy Prometheus for collecting metrics from the LLM platform services.

## Dependencies

- 02_create_docker_compose_skeleton

## Steps

1. Create `data/prometheus/prometheus.yml` with a basic Prometheus configuration, including scraping its own metrics.
2. Add a `prometheus` service definition to `docker-compose.yml`.
3. Mount `data/prometheus/prometheus.yml` into the Prometheus container.
4. Configure persistent storage for Prometheus in `data/prometheus`.
5. Expose port `9090` internally within the Docker network.
6. Add a health check to the service.

## Expected Outcome

The Prometheus container is running, healthy, and accessible, with its own metrics being scraped.

## Verification

```bash
docker compose up -d prometheus
docker compose ps -q prometheus | xargs docker inspect --format '{{.State.Health.Status}}' | grep -q "healthy"
curl -f http://localhost:9090/graph # Check if Prometheus UI is accessible
```

## Outputs

- `prometheus_container_name`: `prometheus`
- `prometheus_port`: `9090`
---