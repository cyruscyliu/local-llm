# Task 11: Setup Logging

## Goal

Configure centralized logging for all services so logs are accessible for debugging and automation.

## Dependencies

- `10_setup_monitoring`

## Steps

1. Configure Docker logging driver for all services
   - Use `json-file` driver with max-size and max-file limits
   - Add logging config to each service in `docker/docker-compose.yml`
2. Optionally deploy Loki for log aggregation
   - Image: `grafana/loki:latest`
   - Port: 3100 (internal only)
   - Volume: `data/loki`
   - Network: `llm-platform`
3. If using Loki, add Promtail as the log shipper
   - Image: `grafana/promtail:latest`
   - Mount Docker socket for container log collection
   - Config at `configs/promtail/promtail.yml`
4. Create `configs/logging.md` documenting how to access logs

## Expected Outcome

- All container logs are size-limited and rotated
- Logs are queryable (via `docker logs` at minimum, via Loki if deployed)
- Log retention policy is configured

## Verification

```bash
docker compose -f docker/docker-compose.yml logs --tail=5 vllm
docker compose -f docker/docker-compose.yml logs --tail=5 litellm
```

## Outputs

- `loki_enabled`: true/false
- `loki_host`: "loki" (if deployed)
- `loki_port`: 3100 (if deployed)
