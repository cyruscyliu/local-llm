---
# Task 04: Deploy Redis

## Goal

Deploy the Redis service using Docker Compose, making it available for caching and queues.

## Dependencies

- 02_create_docker_compose_skeleton

## Steps

1. Add a `redis` service definition to `docker-compose.yml`.
2. Configure persistent storage for Redis in the `data/redis` directory.
3. Expose port `6379` internally within the Docker network.
4. Add a health check to the service.

## Expected Outcome

The Redis container is running, healthy, and accessible on the internal Docker network.

## Verification

```bash
docker compose up -d redis
docker compose ps -q redis | xargs docker inspect --format '{{.State.Health.Status}}' | grep -q "healthy"
docker compose exec redis redis-cli ping
```

## Outputs

- `redis_container_name`: `redis`
- `redis_port`: `6379`
---