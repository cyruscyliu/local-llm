# Platform Configuration Checklist

## 1. Service Configuration

Goal: All platform components are stable, deployable, and upgradeable.

### Container Services
- [ ] All services defined in `docker-compose.yml`
- [ ] Each service has a unique name
- [ ] Restart policy set (`restart: unless-stopped`)
- [ ] Service dependencies correct (`depends_on` with conditions)
- [ ] Ports explicitly declared
- [ ] Internal-only services use `expose` instead of `ports` (postgres, redis, qdrant)

### Environment Variables
- [ ] All config params managed via `.env` file
- [ ] No hardcoded secrets in docker-compose.yml or config files
- [ ] `.env` excluded from git (in `.gitignore`)
- [ ] `.env.example` committed as a template

### Data Persistence
- [ ] PostgreSQL data directory mounted (`./data/postgres`)
- [ ] Redis data directory mounted (`./data/redis`)
- [ ] Qdrant data directory mounted (`./data/qdrant`)
- [ ] Prometheus data directory mounted (`./data/prometheus`)
- [ ] Grafana data directory mounted (`./data/grafana`)

### Health Checks
- [ ] Every service has a `healthcheck` defined
- [ ] `start_period` set for slow-starting services (vllm, litellm, open-webui)
- [ ] `depends_on` uses `condition: service_healthy` where needed

---

## 2. Model Configuration

Goal: Models are manageable, replaceable, and scalable.

### Model Management
- [ ] Model names follow a consistent naming convention
- [ ] Model versions are pinned (not `:latest`)
- [ ] Model storage path is unified (`./models/`)

### Inference Parameters (LiteLLM)
- [ ] `max_tokens` configured
- [ ] `temperature` configured
- [ ] `top_p` configured
- [ ] `repetition_penalty` configured (if supported)

### vLLM Engine Parameters
- [ ] `--gpu-memory-utilization` set
- [ ] `--max-model-len` set
- [ ] `--max-num-seqs` set (concurrency limit)
- [ ] `--tensor-parallel-size` set (if multi-GPU)

### Multi-Model Support
- [ ] LiteLLM model routing configured
- [ ] Fallback model defined (optional)

---

## 3. Resource Configuration

Goal: Prevent system resource exhaustion.

### GPU
- [ ] GPU memory utilization limit set in vLLM
- [ ] GPU monitoring enabled (dcgm-exporter)
- [ ] Inference concurrency limited (`--max-num-seqs`)

### CPU / Memory
- [ ] Docker `mem_limit` set on resource-heavy services
- [ ] Docker `cpus` limit set on resource-heavy services

### Storage
- [ ] Disk usage monitoring via node-exporter
- [ ] Log rotation configured (Docker logging driver)

---

## 4. Network Configuration

Goal: Network topology is clear, secure, and scalable.

### Reverse Proxy
- [ ] All external access goes through nginx
- [ ] HTTPS enabled with TLS certificate
- [ ] HTTP-to-HTTPS redirect configured

### API Routing
- [ ] `/` routes to Open WebUI
- [ ] `/api/` or `/litellm/` routes to LiteLLM API
- [ ] WebSocket upgrade headers set for Open WebUI

### Internal Network
- [ ] Custom Docker network defined
- [ ] Database services (postgres, redis, qdrant) not exposed to host
- [ ] vLLM not exposed to host (expose only)

### Service Discovery
- [ ] Services reference each other by container name
- [ ] No hardcoded IPs

---

## 5. Security Configuration

Goal: Prevent abuse and data leakage.

### Authentication
- [ ] LiteLLM API key enabled
- [ ] Open WebUI login enabled
- [ ] Admin account configured

### Authorization
- [ ] Admin / user roles defined in Open WebUI
- [ ] API key permissions scoped

### Rate Limiting
- [ ] Rate limit configured (LiteLLM or nginx)
- [ ] Token quota per user/key (if needed)
- [ ] Request body size limit (nginx `client_max_body_size`)

### Network Security
- [ ] HTTPS enabled
- [ ] Firewall rules restrict access to management ports
- [ ] Internal services not reachable from public network

### Secrets Management
- [ ] All secrets stored in `.env`
- [ ] `.env` not committed to git
- [ ] No secrets in docker-compose.yml, config files, or code
