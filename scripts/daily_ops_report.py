#!/usr/bin/env python3
import json
import os
import re
import socket
import subprocess
import sys
from dataclasses import dataclass
from datetime import date, timedelta
from pathlib import Path
from typing import Iterable
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


ROOT_DIR = Path(__file__).resolve().parent.parent
PROMETHEUS_URL = "http://localhost:9090"


def load_dotenv(path: Path) -> None:
    if not path.exists():
        return
    for raw_line in path.read_text().splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip("'").strip('"')
        os.environ.setdefault(key, value)


def run_cmd(args: list[str]) -> tuple[int, str]:
    try:
        result = subprocess.run(
            args,
            cwd=ROOT_DIR,
            capture_output=True,
            text=True,
            check=False,
        )
    except FileNotFoundError:
        return 127, ""
    return result.returncode, result.stdout.strip()


def strip_ansi(text: str) -> str:
    return re.sub(r"\x1B\[[0-9;]*[mK]", "", text)


def uniq(items: Iterable[str]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for item in items:
        if item and item not in seen:
            seen.add(item)
            result.append(item)
    return result


def fmt_number(value: float | None) -> str:
    if value is None:
        return "N/A"
    if value >= 1_000_000:
        return f"{value / 1_000_000:.2f}M"
    if value >= 1_000:
        return f"{value / 1_000:.1f}k"
    if float(value).is_integer():
        return str(int(value))
    return f"{value:.2f}"


def get_json(url: str, params: dict[str, str] | None = None) -> dict:
    full_url = url
    if params:
        full_url = f"{url}?{urlencode(params)}"
    with urlopen(full_url, timeout=5) as response:
        return json.load(response)


def post_discord(message: str) -> None:
    webhook = os.environ.get("DISCORD_WEBHOOK_URL")
    if not webhook:
        print("daily_ops_report: DISCORD_WEBHOOK_URL is not set; skipping Discord post", file=sys.stderr)
        return
    payload = json.dumps({"content": message}).encode()
    request = Request(webhook, data=payload, headers={"Content-Type": "application/json"})
    try:
        with urlopen(request, timeout=10):
            pass
    except HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        print(
            f"daily_ops_report: Discord webhook request failed with HTTP {exc.code}: {body}",
            file=sys.stderr,
        )
    except URLError:
        print("daily_ops_report: Discord webhook request failed: network error", file=sys.stderr)


@dataclass
class Report:
    overall_status: str = "OK"
    config_summary: str = "N/A"
    runtime_summary: str = "N/A"
    prom_targets_summary: str = "N/A"
    usage_summary: str = "N/A"
    issues: list[str] = None
    actions: list[str] = None

    def __post_init__(self) -> None:
        if self.issues is None:
            self.issues = []
        if self.actions is None:
            self.actions = []

    def escalate_warn(self) -> None:
        if self.overall_status == "OK":
            self.overall_status = "WARN"

    def escalate_action(self) -> None:
        self.overall_status = "ACTION REQUIRED"


def parse_config_summary(report: Report) -> None:
    check_script = ROOT_DIR / "scripts" / "check-config.sh"
    if not check_script.exists():
        return

    code, output = run_cmd(["bash", str(check_script)])
    cleaned = strip_ansi(output)
    total_line = next((line for line in cleaned.splitlines() if "TOTAL:" in line), "")
    if not total_line:
        return

    summary = re.sub(r"^.*TOTAL:\s*", "", total_line)
    summary = re.sub(r"\s+\|\s+", ", ", summary)
    summary = re.sub(r"\s+", " ", summary).strip()
    report.config_summary = summary

    failed_match = re.search(r"(\d+)\s+failed", summary)
    warn_match = re.search(r"(\d+)\s+warnings", summary)

    failed = int(failed_match.group(1)) if failed_match else 0
    warnings = int(warn_match.group(1)) if warn_match else 0

    if failed > 0:
        report.escalate_action()
        report.issues.append("config failures present")
        report.actions.append("fix config failures with ./scripts/check-config.sh")
    elif warnings > 0 or code != 0:
        report.escalate_warn()
        report.issues.append("config warnings present")
        report.actions.append("review config warnings from ./scripts/check-config.sh")


def prom_query(expr: str) -> float | None:
    try:
        payload = get_json(f"{PROMETHEUS_URL}/api/v1/query", {"query": expr})
    except Exception:
        return None
    result = payload.get("data", {}).get("result", [])
    if not result:
        return None
    try:
        return float(result[0]["value"][1])
    except Exception:
        return None


def first_prom_value(expressions: list[str]) -> float | None:
    for expr in expressions:
        value = prom_query(expr)
        if value is not None:
            return value
    return None


def parse_prometheus(report: Report) -> None:
    try:
        targets_payload = get_json(f"{PROMETHEUS_URL}/api/v1/targets")
    except Exception:
        report.prom_targets_summary = "N/A"
        report.usage_summary = "LiteLLM usage metrics unavailable"
        report.escalate_warn()
        report.actions.append("verify Prometheus is reachable on localhost:9090")
        return

    active = targets_payload.get("data", {}).get("activeTargets", [])
    total = len(active)
    up = 0
    down_jobs: list[str] = []
    for target in active:
        if target.get("health") == "up":
            up += 1
        else:
            down_jobs.append(target.get("labels", {}).get("job", "?"))

    if total == 0:
        report.prom_targets_summary = "0 targets configured"
        report.escalate_warn()
        report.actions.append("check Prometheus scrape configuration")
    else:
        down = uniq(down_jobs)
        report.prom_targets_summary = f"{up}/{total} up"
        if down:
            report.prom_targets_summary += f"; down: {', '.join(down)}"
            report.escalate_action()
            report.issues.append(f"Prometheus targets down: {', '.join(down)}")
            report.actions.append("inspect down Prometheus jobs in /targets")

    requests_24h = first_prom_value([
        "sum(increase(litellm_requests_metric[24h]))",
        "sum(increase(litellm_deployment_total_requests_total[24h]))",
    ])
    input_tokens_24h = first_prom_value([
        "sum(increase(litellm_input_tokens_metric[24h]))",
        "sum(increase(litellm_prompt_tokens_metric[24h]))",
    ])
    output_tokens_24h = first_prom_value([
        "sum(increase(litellm_output_tokens_metric[24h]))",
        "sum(increase(litellm_completion_tokens_metric[24h]))",
    ])

    if requests_24h is None:
        report.usage_summary = "LiteLLM usage metrics unavailable"
        return

    usage_parts = [f"{fmt_number(requests_24h)} requests"]
    if input_tokens_24h is not None or output_tokens_24h is not None:
        usage_parts.append(f"{fmt_number(input_tokens_24h)} input tok")
        usage_parts.append(f"{fmt_number(output_tokens_24h)} output tok")
    report.usage_summary = ", ".join(usage_parts)


def parse_runtime(report: Report, project_name: str) -> None:
    docker_available = run_cmd(["docker", "--version"])[0] == 0
    if not docker_available:
        report.runtime_summary = "docker unavailable"
        report.escalate_warn()
        report.actions.append("run the report on the Docker host")
        return

    _, total_out = run_cmd(
        [
            "docker",
            "ps",
            "-a",
            "--filter",
            f"label=com.docker.compose.project={project_name}",
            "--format",
            "{{.Names}}",
        ]
    )
    _, running_out = run_cmd(
        [
            "docker",
            "ps",
            "--filter",
            f"label=com.docker.compose.project={project_name}",
            "--format",
            "{{.Names}}",
        ]
    )
    _, issues_out = run_cmd(
        [
            "docker",
            "ps",
            "-a",
            "--filter",
            f"label=com.docker.compose.project={project_name}",
            "--format",
            "{{.Names}}\t{{.Status}}",
        ]
    )

    total_names = [line for line in total_out.splitlines() if line.strip()]
    running_names = [line for line in running_out.splitlines() if line.strip()]
    issue_names: list[str] = []
    for line in issues_out.splitlines():
        if re.search(r"unhealthy|exited|dead|restarting", line, re.IGNORECASE):
            issue_names.append(line.split("\t", 1)[0])

    if not total_names:
        report.runtime_summary = "no compose containers found"
        report.escalate_warn()
        report.issues.append("no compose containers found")
        report.actions.append("start the stack or verify the compose project name")
        return

    report.runtime_summary = f"{len(running_names)}/{len(total_names)} containers running"
    issue_names = uniq(issue_names)
    if issue_names:
        report.runtime_summary += f"; issues: {', '.join(issue_names)}"
        report.escalate_action()
        report.issues.append(f"container issues: {', '.join(issue_names)}")
        report.actions.append("inspect failing containers with docker compose ps and docker compose logs")


def build_message(report: Report, project_name: str) -> str:
    report_date = (date.today() - timedelta(days=1)).isoformat()
    host_name = socket.gethostname().split(".")[0] or "unknown-host"

    _, branch = run_cmd(["git", "-C", str(ROOT_DIR), "rev-parse", "--abbrev-ref", "HEAD"])
    _, sha = run_cmd(["git", "-C", str(ROOT_DIR), "rev-parse", "--short", "HEAD"])
    branch = branch or "unknown"
    sha = sha or "unknown"

    update_marker = "N/A"
    marker_file = ROOT_DIR / ".last-restart"
    if marker_file.exists():
        update_marker = marker_file.read_text().strip()[:7] or "N/A"

    issue_line = "none" if not report.issues else "; ".join(uniq(report.issues))
    action_line = "none" if not report.actions else "; ".join(uniq(report.actions))

    return "\n".join(
        [
            f"Daily Ops Report ({report_date})",
            f"Status: {report.overall_status}",
            f"Health: config {report.config_summary} | runtime {report.runtime_summary} | prometheus {report.prom_targets_summary}",
            f"Usage (24h): {report.usage_summary}",
            f"Issues: {issue_line}",
            f"Context: project={project_name} host={host_name} {branch}@{sha} last_update={update_marker}",
            f"Action: {action_line}",
        ]
    )


def main() -> int:
    load_dotenv(ROOT_DIR / ".env")
    project_name = os.environ.get("COMPOSE_PROJECT_NAME") or ROOT_DIR.name

    report = Report()
    parse_config_summary(report)
    parse_runtime(report, project_name)
    parse_prometheus(report)

    message = build_message(report, project_name)
    print(message)
    post_discord(message)
    return 0


if __name__ == "__main__":
    sys.exit(main())
