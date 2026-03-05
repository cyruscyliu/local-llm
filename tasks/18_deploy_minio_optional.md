# Task 18: Deploy MinIO (Optional Object Storage)

## Goal

Optionally provide S3-compatible object storage for uploads, datasets, and artifacts (useful for RAG corpora and backups).

## Dependencies

- `02_setup_docker`

## Steps

1. Add a MinIO service to `docker/docker-compose.yml`
   - Image: `minio/minio:latest`
   - Ports: internal only (reverse proxy exposure is optional and should be a separate decision)
   - Volume: `data/minio` for persistence
   - Environment from `.env`:
     - `MINIO_ROOT_USER`
     - `MINIO_ROOT_PASSWORD`
   - Command: `server /data --console-address ":9001"`
   - Health check: `curl -fsS http://localhost:9000/minio/health/ready`
   - Restart policy: `unless-stopped`
   - Network: `llm-platform`
2. Add MinIO variables to `.env.example`
3. Document access in `configs/minio.md` (URL, console port, first-login)

## Expected Outcome

- MinIO starts and reports healthy
- Data persists across restarts
- Credentials are captured via `.env` and documented in `.env.example`

## Verification

```bash
docker compose -f docker/docker-compose.yml ps minio
docker compose -f docker/docker-compose.yml exec minio curl -fsS http://localhost:9000/minio/health/ready > /dev/null
test -f configs/minio.md
grep -q "MINIO_ROOT_USER" .env.example
```

## Outputs

- `container`: "minio"
- `port_api`: 9000
- `port_console`: 9001
- `host`: "minio"

