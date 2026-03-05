---
# Task 03: Deploy PostgreSQL

## Goal

Deploy the PostgreSQL service using Docker Compose, making it available for other services.

## Dependencies

- 02_create_docker_compose_skeleton

## Steps

1. Add a `postgres` service definition to `docker-compose.yml`.
2. Configure persistent storage for PostgreSQL in the `data/postgres` directory.
3. Set environment variables for `POSTGRES_DB`, `POSTGRES_USER`, and `POSTGRES_PASSWORD`.
4. Expose port `5432` internally within the Docker network.
5. Add a health check to the service.

## Expected Outcome

The PostgreSQL container is running, healthy, and accessible on the internal Docker network.

## Verification

```bash
docker compose up -d postgres
docker compose ps -q postgres | xargs docker inspect --format '{{.State.Health.Status}}' | grep -q "healthy"
docker compose exec postgres pg_isready -U postgres
```

## Outputs

- `postgres_container_name`: `postgres`
- `postgres_port`: `5432`
---