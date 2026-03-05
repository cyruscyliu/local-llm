# Task 13: Setup Automation Hooks

## Goal

Create maintenance scripts that can be called by operators or by the autonomous maintenance agent.

## Dependencies

- `09_setup_reverse_proxy`
- `12_setup_grafana_dashboards`

## Steps

1. Create maintenance scripts in `scripts/`:
   - `scripts/restart_vllm.sh` -- restart the vLLM container, wait for health
   - `scripts/restart_litellm.sh` -- restart the LiteLLM container, wait for health
   - `scripts/reload_model.sh` -- trigger model reload on vLLM
   - `scripts/clear_queue.sh` -- flush Redis request queue
   - `scripts/backup_db.sh` -- dump PostgreSQL database
   - `scripts/health_check.sh` -- check all service health endpoints
2. Make all scripts executable and idempotent
3. Each script should:
   - Log its actions with timestamps
   - Exit with appropriate status codes
   - Accept a `--dry-run` flag where applicable
4. Create `scripts/README.md` documenting each script

## Expected Outcome

- All scripts exist and are executable
- Scripts can be run manually or by an agent
- Health check script validates the entire platform

## Verification

```bash
test -x scripts/restart_vllm.sh
test -x scripts/restart_litellm.sh
test -x scripts/reload_model.sh
test -x scripts/clear_queue.sh
test -x scripts/backup_db.sh
test -x scripts/health_check.sh
bash scripts/health_check.sh
```

## Outputs

- `scripts_dir`: "scripts/"
- `health_check`: "scripts/health_check.sh"
