# Task 03: Deploy PostgreSQL

## Goal

Deploy a PostgreSQL instance for storing user data, sessions, API keys, and LiteLLM metadata.

## Dependencies

- `02_setup_docker`

## Steps

1. Add PostgreSQL service to `docker/docker-compose.yml`
   - Image: `postgres:16-alpine`
   - Port: 5432 (internal only, not exposed to host)
   - Volume: `data/postgres` for persistence
   - Environment: read from `.env` (POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB)
   - Health check: `pg_isready`
   - Restart policy: `unless-stopped`
   - Network: `llm-platform`
2. Add PostgreSQL credentials to `.env.example`
3. Create initialization SQL script at `configs/postgres/init.sql` if needed

## Expected Outcome

- PostgreSQL container starts and is healthy
- Data persists across container restarts
- Container is only accessible within the Docker network

## Verification

```bash
docker compose -f docker/docker-compose.yml ps postgres
docker compose -f docker/docker-compose.yml exec postgres pg_isready
```

## Outputs

- `container`: "postgres"
- `port`: 5432
- `host`: "postgres" (Docker DNS)
