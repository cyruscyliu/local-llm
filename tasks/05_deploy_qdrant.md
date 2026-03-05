# Task 05: Deploy Qdrant

## Goal

Deploy a Qdrant vector database for document RAG (embeddings storage and semantic search).

## Dependencies

- `02_setup_docker`

## Steps

1. Add Qdrant service to `docker/docker-compose.yml`
   - Image: `qdrant/qdrant:latest`
   - Ports: 6333 (HTTP), 6334 (gRPC) -- internal only
   - Volume: `data/qdrant` for persistence
   - Health check: `curl -f http://localhost:6333/healthz`
   - Restart policy: `unless-stopped`
   - Network: `llm-platform`
2. Add Qdrant configuration to `.env.example` if needed

## Expected Outcome

- Qdrant container starts and is healthy
- Collections persist across restarts
- REST and gRPC APIs accessible within the Docker network

## Verification

```bash
docker compose -f docker/docker-compose.yml ps qdrant
docker compose -f docker/docker-compose.yml exec qdrant curl -sf http://localhost:6333/healthz
```

## Outputs

- `container`: "qdrant"
- `port_http`: 6333
- `port_grpc`: 6334
- `host`: "qdrant"
