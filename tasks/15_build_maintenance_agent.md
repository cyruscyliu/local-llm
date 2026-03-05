# Task 15: Build Autonomous Maintenance Agent

## Goal

Create the maintenance agent that monitors the running platform and takes
corrective action, following the design in `docs/guide.md` (Maintenance Agent section).

## Dependencies

- `13_setup_automation_hooks`
- `10_setup_monitoring`

## Steps

1. Create the maintenance agent script at `scripts/maintenance-agent.sh`
   - Poll loop on a configurable interval (default: 60 seconds)
   - Query Prometheus metrics via API (`http://prometheus:9090/api/v1/query`)
   - Check health endpoints for all services
   - Evaluate rules from `configs/maintenance-rules.yaml`
   - Execute approved scripts from `scripts/` when rules trigger
   - Log every action to `data/maintenance-agent/actions.log`
   - Respect cooldown periods between restarts
2. Create rules configuration at `configs/maintenance-rules.yaml`
   - Define condition-action pairs:
     ```yaml
     rules:
       - name: gpu_memory_high
         condition: "gpu_memory_percent > 95"
         action: "scripts/restart_vllm.sh"
         cooldown_minutes: 5
       - name: queue_overload
         condition: "queue_length > 50"
         action: "scripts/clear_queue.sh"
         cooldown_minutes: 2
       - name: high_error_rate
         condition: "error_rate_5m > 0.05"
         action: "scripts/restart_litellm.sh"
         cooldown_minutes: 5
       - name: health_check_failed
         condition: "health_check_failures > 3"
         action: "scripts/restart_${service}.sh"
         cooldown_minutes: 5
       - name: disk_full
         condition: "disk_usage_percent > 90"
         action: "escalate"
         cooldown_minutes: 60
     ```
3. Create a helper library at `scripts/lib/maintenance_utils.sh`
   - `query_prometheus` -- query a PromQL expression
   - `check_health` -- check a service health endpoint
   - `check_cooldown` -- verify cooldown has elapsed
   - `log_action` -- write structured JSON log entry
   - `escalate` -- write to escalations file and optionally send webhook
4. Create escalation handler
   - Write to `data/maintenance-agent/escalations.json`
   - Optional webhook notification (Slack, email) via `configs/maintenance-agent.yaml`
5. Create rate limiter state file at `data/maintenance-agent/cooldowns.json`
   - Track last action time per rule
   - Enforce max restarts per service per hour
6. Create systemd unit file at `infra/maintenance-agent.service`
   - Long-running service with auto-restart
   - After docker.service
7. Create `scripts/maintenance-agent-wrapper.sh`
   - Set up logging
   - Lock file to prevent concurrent runs

## Expected Outcome

- Agent polls metrics and health endpoints on interval
- Rules trigger corrective scripts when conditions are met
- Cooldown prevents restart loops
- All actions are logged with structured JSON
- Escalation mechanism alerts humans for unresolvable issues
- Systemd unit allows running as a persistent service

## Verification

```bash
test -f scripts/maintenance-agent.sh && test -x scripts/maintenance-agent.sh
test -f configs/maintenance-rules.yaml
test -f scripts/lib/maintenance_utils.sh
test -f infra/maintenance-agent.service
# Dry run: agent should evaluate rules without taking action
bash scripts/maintenance-agent.sh --dry-run | grep -q "rules_evaluated"
```

## Outputs

- `agent_script`: "scripts/maintenance-agent.sh"
- `rules_config`: "configs/maintenance-rules.yaml"
- `service_unit`: "infra/maintenance-agent.service"
- `action_log`: "data/maintenance-agent/actions.log"
