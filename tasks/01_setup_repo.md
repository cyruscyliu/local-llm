# Task 01: Setup Repository Structure

## Goal

Create the directory layout and base configuration files for the LLM platform project.

## Dependencies

None.

## Steps

1. Create the directory structure:
   - `docker/` -- compose files and Dockerfiles
   - `infra/` -- infrastructure scripts
   - `configs/` -- service configuration files
   - `scripts/` -- maintenance and helper scripts
   - `data/` -- persistent data volumes (gitignored)
   - `models/` -- model storage (gitignored)
2. Create a `.gitignore` with entries for `data/`, `models/`, `.env`, `*.log`
3. Create a `.env.example` with placeholder environment variables for all services
4. Create a base `docker/docker-compose.yml` with network definitions only (no services yet)
5. Create a `README.md` at the project root:
   - Project name and one-line description
   - Prerequisites (Docker, NVIDIA Container Toolkit, etc.)
   - Quickstart (clone, copy `.env.example` to `.env`, fill in values, run)
   - Directory layout overview
   - Links to `docs/project.md` for architecture and `docs/guide.md` for development workflow
   - License section (placeholder)
6. Create a `SECURITY.md` at the project root:
   - Supported versions / scope
   - How to report vulnerabilities (private disclosure process)
   - Security-relevant configuration (`.env` secrets, network exposure, API keys)
   - What is and is not exposed to the network
   - Responsible disclosure expectations

## Expected Outcome

- All directories exist
- `.gitignore` prevents data/model/secret leakage
- `.env.example` documents required variables
- A shared Docker network (`llm-platform`) is defined in compose
- `README.md` provides a usable entry point for new users
- `SECURITY.md` documents how to handle security issues

## Verification

```bash
test -d docker && test -d infra && test -d configs && test -d scripts
test -f .gitignore && test -f .env.example
test -f docker/docker-compose.yml
test -f README.md && test -f SECURITY.md
grep -q "llm-platform" docker/docker-compose.yml
```

## Outputs

- `network_name`: "llm-platform"
- `compose_file`: "docker/docker-compose.yml"
