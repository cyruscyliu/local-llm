# Task 16: Enable Document RAG (Qdrant Wiring + Reproducible Config)

## Goal

Make Document RAG a first-class, reproducible capability by wiring the platform's vector DB (Qdrant) into the app layer and documenting the exact configuration knobs.

## Dependencies

- `05_deploy_qdrant`
- `08_deploy_openwebui`

## Steps

1. Add a short, concrete RAG configuration doc at `configs/rag.md`:
   - Which component owns ingestion (Open WebUI vs a dedicated ingestion service)
   - Qdrant URL, collection naming, and any auth settings
   - Embedding model choice and where it runs (vLLM vs external)
   - A minimal “hello RAG” flow (upload doc → index → ask a question)
2. Add RAG-related placeholders to `.env.example` so configuration is not hidden:
   - `RAG_QDRANT_URL` (default: `http://qdrant:6333`)
   - `RAG_QDRANT_COLLECTION` (default: `documents`)
   - `RAG_EMBEDDING_MODEL` (explicitly required; no implicit defaults)
3. Wire the chosen settings into the relevant service configuration:
   - If Open WebUI supports Qdrant directly, set the required env vars in compose.
   - If Open WebUI does not, document that limitation in `configs/rag.md` and add a follow-up task (do not “pretend enablement”).

## Expected Outcome

- There is a single source of truth for how RAG is configured (`configs/rag.md`).
- RAG config is visible via `.env.example`.
- Qdrant connectivity and assumptions are explicit (no tribal knowledge).

## Verification

```bash
test -f configs/rag.md
grep -q "RAG_QDRANT_URL" .env.example
grep -q "RAG_EMBEDDING_MODEL" .env.example
docker compose -f docker/docker-compose.yml ps qdrant
docker compose -f docker/docker-compose.yml exec qdrant curl -fsS http://localhost:6333/healthz > /dev/null
```

## Outputs

- `rag_doc`: "configs/rag.md"
- `qdrant_url_default`: "http://qdrant:6333"
- `qdrant_collection_default`: "documents"

