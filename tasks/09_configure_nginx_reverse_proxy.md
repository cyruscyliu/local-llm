---
# Task 09: Configure Nginx Reverse Proxy

## Goal

Set up Nginx as a reverse proxy to route public traffic to Open WebUI and LiteLLM.

## Dependencies

- 08_deploy_open_webui
- 07_deploy_litellm

## Steps

1. Create `nginx/nginx.conf` with server blocks to:
   - Route requests to `/` to the `open-webui` service on port `3000`.
   - Route requests to `/api` to the `litellm` service on port `4000`.
2. Add an `nginx` service definition to `docker-compose.yml`.
3. Mount `nginx/nginx.conf` into the Nginx container.
4. Map public port `80` (or `443` for HTTPS, but start with HTTP for simplicity) to the Nginx container's port `80`.
5. Add a health check to the service.

## Expected Outcome

The Nginx container is running, healthy, and correctly routing requests to Open WebUI and LiteLLM.

## Verification

```bash
docker-compose up -d nginx
docker-compose ps -q nginx | xargs docker inspect --format '{{.State.Health.Status}}' | grep -q "healthy"
curl -f http://localhost/ # Should return content from Open WebUI
curl -f http://localhost/api/health # Should return health status from LiteLLM
```

## Outputs

- `nginx_container_name`: `nginx`
- `nginx_public_port`: `80` (or `443` if HTTPS is configured)
---