---
# Task 05: Deploy Qdrant

## Goal

Deploy the Qdrant vector database service using Docker Compose for RAG capabilities.

## Dependencies

- 02_create_docker_compose_skeleton

## Steps

1. Add a `qdrant` service definition to `docker-compose.yml`.
2. Configure persistent storage for Qdrant in the `data/qdrant` directory.
3. Expose port `6333` internally within the Docker network.
4. Add a health check to the service.

## Expected Outcome

The Qdrant container is running, healthy, and accessible on the internal Docker network.

## Verification

```bash
docker-compose up -d qdrant
docker-compose ps -q qdrant | xargs docker inspect --format '{{.State.Health.Status}}' | grep -q "healthy"
curl -f http://localhost:6333/healthz # Assuming internal exposure allows localhost access from host or another container
```

## Outputs

- `qdrant_container_name`: `qdrant`
- `qdrant_port`: `6333`
---