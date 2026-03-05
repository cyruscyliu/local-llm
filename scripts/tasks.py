#!/usr/bin/env python3
"""
Small task/status helper for this repo.

Design goals:
- Zero dependencies (stdlib only).
- Safe writes (atomic replace).
- Human- and agent-friendly output.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import tempfile
from dataclasses import dataclass
from typing import Any, Dict, Iterable, List, Optional, Tuple


STATUSES = {"pending", "in_progress", "done", "failed"}


@dataclass(frozen=True)
class Task:
    id: str
    status: str
    depends_on: List[str]
    retries: int
    max_retries: int
    outputs: Dict[str, Any]
    error: Optional[str]


def _read_json(path: str) -> Dict[str, Any]:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def _atomic_write_json(path: str, data: Dict[str, Any]) -> None:
    directory = os.path.dirname(path) or "."
    fd, tmp = tempfile.mkstemp(prefix=os.path.basename(path) + ".", dir=directory)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
            f.write("\n")
        os.replace(tmp, path)
    finally:
        try:
            if os.path.exists(tmp):
                os.unlink(tmp)
        except OSError:
            pass


def _load_tasks(status_path: str) -> Tuple[Dict[str, Any], List[Task]]:
    raw = _read_json(status_path)
    tasks_raw = raw.get("tasks", [])
    tasks: List[Task] = []
    for t in tasks_raw:
        tasks.append(
            Task(
                id=t["id"],
                status=t["status"],
                depends_on=list(t.get("depends_on", [])),
                retries=int(t.get("retries", 0)),
                max_retries=int(t.get("max_retries", 3)),
                outputs=dict(t.get("outputs", {})),
                error=t.get("error", None),
            )
        )
    return raw, tasks


def _task_index(tasks: Iterable[Task]) -> Dict[str, Task]:
    idx: Dict[str, Task] = {}
    dupes = set()
    for t in tasks:
        if t.id in idx:
            dupes.add(t.id)
        idx[t.id] = t
    if dupes:
        raise SystemExit(f"duplicate task ids in status.json: {sorted(dupes)}")
    return idx


def _is_retryable(task: Task) -> bool:
    return task.status == "failed" and task.retries < task.max_retries


def _runnable(tasks: List[Task]) -> List[Task]:
    idx = _task_index(tasks)

    def done(task_id: str) -> bool:
        t = idx.get(task_id)
        return t is not None and t.status == "done"

    out: List[Task] = []
    for t in tasks:
        if t.status != "pending" and not _is_retryable(t):
            continue
        if all(done(dep) for dep in t.depends_on):
            out.append(t)
    return out


def _print_lines(lines: Iterable[str]) -> None:
    for line in lines:
        sys.stdout.write(line)
        sys.stdout.write("\n")


def cmd_summary(status_path: str) -> int:
    _, tasks = _load_tasks(status_path)
    counts: Dict[str, int] = {s: 0 for s in STATUSES}
    unknown: Dict[str, int] = {}
    for t in tasks:
        if t.status in counts:
            counts[t.status] += 1
        else:
            unknown[t.status] = unknown.get(t.status, 0) + 1

    runnable = _runnable(tasks)
    total = len(tasks)
    _print_lines(
        [
            f"total\t{total}",
            *(f"{s}\t{counts[s]}" for s in sorted(counts)),
            *(f"unknown({k})\t{v}" for k, v in sorted(unknown.items())),
            f"runnable\t{len(runnable)}",
        ]
    )
    if runnable:
        sys.stdout.write("next\t")
        sys.stdout.write(runnable[0].id)
        sys.stdout.write("\n")
    return 0


def cmd_runnable(status_path: str) -> int:
    _, tasks = _load_tasks(status_path)
    _print_lines([t.id for t in _runnable(tasks)])
    return 0


def cmd_next(status_path: str) -> int:
    _, tasks = _load_tasks(status_path)
    runnable = _runnable(tasks)
    if not runnable:
        return 1
    sys.stdout.write(runnable[0].id)
    sys.stdout.write("\n")
    return 0


def _update_task(
    raw: Dict[str, Any],
    task_id: str,
    *,
    status: Optional[str] = None,
    retries: Optional[int] = None,
    error: Any = None,
    outputs_kv: Optional[List[Tuple[str, str]]] = None,
) -> None:
    tasks_raw = raw.get("tasks", [])
    for t in tasks_raw:
        if t.get("id") != task_id:
            continue
        if status is not None:
            if status not in STATUSES:
                raise SystemExit(f"invalid status: {status} (expected one of {sorted(STATUSES)})")
            t["status"] = status
        if retries is not None:
            t["retries"] = int(retries)
        if error is not None:
            t["error"] = error
        if outputs_kv:
            out = t.get("outputs") or {}
            if not isinstance(out, dict):
                out = {}
            for k, v in outputs_kv:
                out[k] = v
            t["outputs"] = out
        return
    raise SystemExit(f"task not found: {task_id}")


def cmd_set(status_path: str, task_id: str, status: str, error: Optional[str]) -> int:
    raw, _ = _load_tasks(status_path)
    _update_task(raw, task_id, status=status, error=error)
    _atomic_write_json(status_path, raw)
    return 0


def cmd_reset(status_path: str, task_id: str) -> int:
    raw, _ = _load_tasks(status_path)
    _update_task(raw, task_id, status="pending", retries=0, error=None)
    _atomic_write_json(status_path, raw)
    return 0


def cmd_output(status_path: str, task_id: str, kvs: List[str]) -> int:
    if not kvs:
        raise SystemExit("no outputs provided (expected KEY=VALUE ...)")
    parsed: List[Tuple[str, str]] = []
    for kv in kvs:
        if "=" not in kv:
            raise SystemExit(f"invalid output: {kv} (expected KEY=VALUE)")
        k, v = kv.split("=", 1)
        k = k.strip()
        if not k:
            raise SystemExit(f"invalid output key: {kv}")
        parsed.append((k, v))

    raw, _ = _load_tasks(status_path)
    _update_task(raw, task_id, outputs_kv=parsed)
    _atomic_write_json(status_path, raw)
    return 0


def main(argv: Optional[List[str]] = None) -> int:
    p = argparse.ArgumentParser(prog="tasks.py", description="Helper for tasks/status.json")
    p.add_argument(
        "--status",
        "--status-file",
        dest="status_path",
        default=os.path.join("tasks", "status.json"),
        help="Path to status.json (default: tasks/status.json)",
    )

    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("summary", help="Print counts and next runnable task")
    sub.add_parser("runnable", help="List runnable task ids (pending with deps done)")
    sub.add_parser("next", help="Print the next runnable task id (exit 1 if none)")

    p_set = sub.add_parser("set", help="Set task status")
    p_set.add_argument("id", help="Task id (e.g. 03_deploy_postgres)")
    p_set.add_argument("status", choices=sorted(STATUSES), help="New status")
    p_set.add_argument("--error", default=None, help="Set an error message (or clear with empty string)")

    p_reset = sub.add_parser("reset", help="Reset task to pending, clear retries and error")
    p_reset.add_argument("id", help="Task id")

    p_out = sub.add_parser("output", help="Set outputs (KEY=VALUE ...)")
    p_out.add_argument("id", help="Task id")
    p_out.add_argument("kv", nargs="+", help="One or more KEY=VALUE pairs")

    args = p.parse_args(argv)
    status_path = args.status_path

    if args.cmd == "summary":
        return cmd_summary(status_path)
    if args.cmd == "runnable":
        return cmd_runnable(status_path)
    if args.cmd == "next":
        return cmd_next(status_path)
    if args.cmd == "set":
        err = args.error
        if err == "":
            err = None
        return cmd_set(status_path, args.id, args.status, err)
    if args.cmd == "reset":
        return cmd_reset(status_path, args.id)
    if args.cmd == "output":
        return cmd_output(status_path, args.id, args.kv)

    raise SystemExit(f"unknown command: {args.cmd}")


if __name__ == "__main__":
    raise SystemExit(main())
