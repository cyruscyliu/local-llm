# Autonomous Maintenance Agent

This document describes the design for an autonomous maintenance agent
that monitors and maintains a running platform without human interaction.

This is a reusable pattern -- it can be applied to any Dockerized
service platform with health endpoints and metrics.

------------------------------------------------------------------------

## 1. Purpose

The maintenance agent keeps the platform healthy after deployment. It
operates continuously, watching metrics and logs, and taking corrective
action when problems are detected.

Unlike the coding agent (see [autonomous-coding-agent.md](autonomous-coding-agent.md))
which builds and deploys, the maintenance agent operates on a running
system.

------------------------------------------------------------------------

## 2. Inputs

The agent reads from:

-   **Metrics** -- collected by Prometheus or equivalent (e.g., resource
    utilization, latency, throughput, queue length, error rate)
-   **Health endpoints** -- `/health`, `/status` on each service
-   **Container state** -- `docker ps`, container logs, restart counts
-   **Application logs** -- from all managed services

------------------------------------------------------------------------

## 3. Actions

The agent can execute a predefined set of maintenance scripts. Examples:

| Script                  | Purpose                              |
|-------------------------|--------------------------------------|
| `restart_<service>.sh`  | Restart a specific service container |
| `reload_config.sh`      | Reload configuration without restart |
| `clear_queue.sh`        | Clear stuck requests from queue      |
| `backup_db.sh`          | Back up the database                 |

The agent must never run arbitrary commands. It only calls scripts from
the approved set, defined in the project's `scripts/` directory.

------------------------------------------------------------------------

## 4. Rules Engine

The agent follows condition-action rules:

```
IF resource_usage > threshold
THEN restart_<service>.sh

IF queue_length > threshold
THEN clear_queue.sh

IF error_rate > threshold for N minutes
THEN analyze logs, restart_<service>.sh

IF health_check fails N times
THEN restart affected service

IF disk_usage > threshold
THEN alert human (do not act)
```

Rules should be defined in a configuration file (e.g.,
`configs/maintenance-rules.yaml`) so they can be updated without
changing agent code.

------------------------------------------------------------------------

## 5. Safety Boundaries

The agent must:

-   Only execute approved scripts from `scripts/`
-   Never modify application code or configuration
-   Never delete data volumes
-   Limit restart frequency (cooldown period between restarts)
-   Escalate to a human if the same issue recurs more than N times

------------------------------------------------------------------------

## 6. Cooldown and Rate Limiting

To prevent restart loops:

-   Minimum 5 minutes between restarts of the same service
-   Maximum 3 restarts per service per hour
-   After hitting the limit, mark the service as `needs_human_review`
    and stop acting on it

------------------------------------------------------------------------

## 7. Logging and Audit Trail

Every action the agent takes is logged:

```json
{
  "timestamp": "2025-01-15T02:15:00Z",
  "trigger": "resource_usage > 95%",
  "action": "restart_<service>.sh",
  "result": "success",
  "notes": "Usage dropped to normal after restart"
}
```

Logs are written to a file (e.g., `data/maintenance-agent/actions.log`)
and optionally pushed to a log aggregation system for dashboard
visibility.

------------------------------------------------------------------------

## 8. Human Escalation

The agent escalates when:

-   A service has been restarted more than the allowed limit
-   An issue does not resolve after corrective action
-   The condition is outside the rules engine (unknown error pattern)
-   Disk or hardware issues are detected

Escalation methods:

-   Write to an escalations file (e.g., `data/maintenance-agent/escalations.json`)
-   Send webhook notification (Slack, email, etc.)
-   Create an alert annotation in the monitoring dashboard

------------------------------------------------------------------------

## 9. Running the Agent

The maintenance agent runs as a long-lived process or systemd service:

```ini
[Unit]
Description=Platform Maintenance Agent
After=docker.service

[Service]
ExecStart=/path/to/maintenance-agent
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
```

It polls metrics on a configurable interval (default: 60 seconds).

------------------------------------------------------------------------

## 10. Relationship to Coding Agent

| Aspect       | Coding Agent                    | Maintenance Agent              |
|--------------|---------------------------------|--------------------------------|
| When         | During deployment               | After deployment               |
| What         | Builds infrastructure           | Monitors and repairs           |
| Input        | Task files in `tasks/`          | Metrics, logs, health checks   |
| Output       | Code, configs, containers       | Restarts, alerts, log entries  |
| Runs         | Until all tasks are done        | Continuously                   |
| Modifies     | `docker/`, `infra/`, `configs/` | Nothing (only runs scripts)    |
