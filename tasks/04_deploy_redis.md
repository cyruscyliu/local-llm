# Task 04: Deploy Redis

## Goal

Deploy a Redis instance for caching, request queuing, and rate limiting.

## Dependencies

- `02_setup_docker`

## Steps

1. Add Redis service to `docker/docker-compose.yml`
   - Image: `redis:7-alpine`
   - Port: 6379 (internal only)
   - Volume: `data/redis` for persistence
   - Health check: `redis-cli ping`
   - Restart policy: `unless-stopped`
   - Network: `llm-platform`
   - Enable append-only file persistence (`--appendonly yes`)
2. Add any Redis configuration to `.env.example` if needed

## Expected Outcome

- Redis container starts and is healthy
- Data persists across restarts
- Container is only accessible within the Docker network

## Verification

```bash
docker compose -f docker/docker-compose.yml ps redis
docker compose -f docker/docker-compose.yml exec redis redis-cli ping
```

## Outputs

- `container`: "redis"
- `port`: 6379
- `host`: "redis"
