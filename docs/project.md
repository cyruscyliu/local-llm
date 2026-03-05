# Lab LLM Platform

This document describes a **lab LLM platform** running on a
**single RTX 4090 workstation**.

## Goals

-   Multi-user internal LLM service
-   Chat web portal
-   OpenAI-compatible APIs
-   Document RAG capability
-   Observability and monitoring
-   Autonomous deployment and maintenance via AI agents

## Expected Capacity

-   6--10 concurrent users
-   30--40 total lab members

------------------------------------------------------------------------

# 1. High-Level Architecture

Users │ ▼ Reverse Proxy (Nginx / Traefik) │ ├── Open WebUI (Web Portal)
│ └── LiteLLM (API Gateway) │ ▼ vLLM Server │ ▼ RTX 4090 GPU

Supporting infrastructure:

-   PostgreSQL -- metadata and user data
-   Redis -- caching and queues
-   Qdrant -- vector database for RAG
-   Prometheus -- metrics collection
-   Grafana -- monitoring dashboards
-   MinIO -- object storage (optional)

------------------------------------------------------------------------

# 2. Development & Deployment Model

Development occurs on a **separate machine** from the GPU server.

Developer Machine │ ├─ code development ├─ docker builds └─ git
repository │ ▼ Git Server (GitHub / GitLab) │ ▼ GPU Server │ ├─ docker
runtime ├─ deployed services └─ model inference

Benefits:

-   Development isolated from production
-   Reproducible deployments
-   Automated updates via coding agent (see [autonomous-coding-agent.md](autonomous-coding-agent.md))

------------------------------------------------------------------------

# 3. Core Services

Deploy the following services:

-   Open WebUI
-   LiteLLM
-   vLLM
-   PostgreSQL
-   Redis
-   Qdrant

Responsibilities:

Open WebUI:
-   chat interface
-   conversation history
-   prompt templates
-   file uploads

LiteLLM:
-   API gateway
-   API keys
-   rate limiting
-   model routing

vLLM:
-   GPU inference
-   batching
-   streaming responses

PostgreSQL:
-   users
-   sessions
-   messages
-   API keys

Redis:
-   caching
-   request queue
-   rate limiting

Qdrant:
-   embeddings
-   document retrieval
-   semantic search

------------------------------------------------------------------------

# 4. Networking

Internal ports:

Open WebUI → 3000\
LiteLLM → 4000\
vLLM → 8000\
PostgreSQL → 5432\
Redis → 6379\
Qdrant → 6333

Public entrypoint:

HTTPS → 443

Reverse proxy routes:

/ → Open WebUI\
/api → LiteLLM

------------------------------------------------------------------------

# 5. GPU Inference Setup

Run vLLM server:

python -m vllm.entrypoints.openai.api_server --model
/models/your-9b-model --gpu-memory-utilization 0.9 --max-model-len 8192

Capabilities:

-   streaming responses
-   batching
-   multi-user concurrency

------------------------------------------------------------------------

# 6. Directory Layout

llm-platform/

docker-compose.yml\
nginx/nginx.conf

configs/

litellm.yaml\
vllm_config.yaml

models/

data/

postgres/\
redis/\
qdrant/\
prometheus/\
grafana/

------------------------------------------------------------------------

# 7. Reliability

Enable container auto-restart:

restart: always

Health endpoints should exist:

/health\
/status\
/metrics

These allow automation and monitoring.

------------------------------------------------------------------------

# 8. Observability & Monitoring

Deploy:

-   Prometheus
-   Grafana
-   Node exporter
-   NVIDIA GPU exporter

Metrics collected:

-   GPU utilization
-   VRAM usage
-   request latency
-   tokens/sec
-   queue length
-   error rate

------------------------------------------------------------------------

# 9. Logging

Ensure all services expose logs:

-   docker logs
-   file logs
-   optional Loki integration

Log sources:

-   vLLM
-   LiteLLM
-   reverse proxy
-   system metrics

Logs enable debugging and agent-driven automation.

------------------------------------------------------------------------

# 10. Monitoring Dashboards

Grafana dashboards should display:

-   GPU utilization
-   VRAM usage
-   request latency
-   token throughput
-   queue size
-   active users

Alert examples:

GPU memory \> 90%\
queue length \> 20\
error rate \> 5%

------------------------------------------------------------------------

# 11. Automation Hooks

Expose control mechanisms for agents and operators.

Example maintenance scripts:

restart_vllm.sh\
restart_litellm.sh\
reload_model.sh\
clear_queue.sh

Example command:

docker restart vllm

These scripts are callable by the autonomous maintenance agent
(see [autonomous-maintenance-agent.md](autonomous-maintenance-agent.md)).

------------------------------------------------------------------------

# 12. Agents

This project uses two types of autonomous agents:

1.  **Coding Agent** -- builds and deploys the platform by working
    through task files. See [autonomous-coding-agent.md](autonomous-coding-agent.md).

2.  **Maintenance Agent** -- monitors and maintains the running platform.
    See [autonomous-maintenance-agent.md](autonomous-maintenance-agent.md).

------------------------------------------------------------------------

# 13. Outcome

The system provides:

-   Chat web portal
-   OpenAI-compatible APIs
-   Document RAG
-   Multi-user GPU inference
-   Metrics dashboards
-   Monitoring and logging
-   Automation-ready infrastructure
-   Autonomous task-driven deployment

Lab members interact only with:

-   Web UI
-   APIs

Infrastructure deployment and maintenance are automated by agents.
