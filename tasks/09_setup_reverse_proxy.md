# Task 09: Setup Reverse Proxy

## Goal

Deploy an Nginx reverse proxy to route external HTTPS traffic to Open WebUI and LiteLLM.

## Dependencies

- `07_deploy_litellm`
- `08_deploy_openwebui`

## Steps

1. Create Nginx config at `configs/nginx/nginx.conf`
   - Route `/` to Open WebUI (`http://openwebui:8080`)
   - Route `/api` to LiteLLM (`http://litellm:4000`)
   - Enable WebSocket support for chat streaming
   - Set appropriate proxy headers (X-Real-IP, X-Forwarded-For, Host)
   - Configure SSL/TLS (self-signed cert initially, or Let's Encrypt)
   - Set client max body size for file uploads
2. Add Nginx service to `docker/docker-compose.yml`
   - Image: `nginx:alpine`
   - Ports: 80, 443 (exposed to host)
   - Volume mounts: nginx config, SSL certs
   - Health check: `curl -f http://localhost/health`
   - Restart policy: `unless-stopped`
   - Network: `llm-platform`
   - Depends on: openwebui, litellm
3. Create a script at `scripts/generate_self_signed_cert.sh` for initial SSL setup

## Expected Outcome

- HTTPS traffic is routed to the correct services
- WebSocket connections work for chat streaming
- Single entrypoint on ports 80/443

## Verification

```bash
docker compose -f docker/docker-compose.yml ps nginx
curl -sf -k https://localhost/ | head -c 100
curl -sf -k https://localhost/api/health
```

## Outputs

- `container`: "nginx"
- `port_http`: 80
- `port_https`: 443
- `public_url`: "https://localhost"
