#!/usr/bin/env python3
"""Gemini agent runtime -- executes tasks via Gemini function calling API.

Provides the LLM with tools (read_file, write_file, run_command, list_files)
so it can autonomously implement coding tasks, similar to Claude Code or Codex.

Usage:
    echo "prompt text" | GEMINI_API_KEY=... python3 scripts/lib/gemini_agent.py
"""

import json
import os
import subprocess
import sys
import urllib.error
import urllib.request

API_KEY = os.environ.get("GEMINI_API_KEY", "")
MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")
BASE_URL = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}"
MAX_TURNS = int(os.environ.get("GEMINI_MAX_TURNS", "30"))
CMD_TIMEOUT = int(os.environ.get("GEMINI_CMD_TIMEOUT", "120"))

TOOLS = [
    {
        "function_declarations": [
            {
                "name": "read_file",
                "description": "Read the contents of a file (relative to repo root).",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "path": {
                            "type": "string",
                            "description": "File path relative to repo root",
                        }
                    },
                    "required": ["path"],
                },
            },
            {
                "name": "write_file",
                "description": "Write content to a file. Creates parent directories as needed.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "path": {
                            "type": "string",
                            "description": "File path relative to repo root",
                        },
                        "content": {
                            "type": "string",
                            "description": "Full file content to write",
                        },
                    },
                    "required": ["path", "content"],
                },
            },
            {
                "name": "run_command",
                "description": "Run a shell command and return stdout/stderr. Use for verification, inspecting state, or running build tools. Do NOT use for destructive operations.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "command": {
                            "type": "string",
                            "description": "Shell command to execute",
                        }
                    },
                    "required": ["command"],
                },
            },
            {
                "name": "list_files",
                "description": "List files and directories at the given path.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "path": {
                            "type": "string",
                            "description": "Directory path relative to repo root (default: '.')",
                        }
                    },
                    "required": [],
                },
            },
        ]
    }
]

BLOCKED_PATTERNS = [
    "rm -rf /",
    "rm -rf ~",
    "mkfs",
    "dd if=/dev",
    ":(){:|:&};:",
    "> /dev/sd",
]


def log(msg):
    print(f"[gemini-agent] {msg}", file=sys.stderr, flush=True)


def api_call(contents):
    url = f"{BASE_URL}:generateContent"
    body = {
        "contents": contents,
        "tools": TOOLS,
        "generationConfig": {
            "temperature": 0.2,
        },
    }

    data = json.dumps(body).encode()
    req = urllib.request.Request(
        url,
        data=data,
        headers={
            "Content-Type": "application/json",
            "x-goog-api-key": API_KEY,
        },
    )

    try:
        with urllib.request.urlopen(req, timeout=300) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        error_body = e.read().decode() if e.fp else ""
        log(f"API error {e.code}: {error_body[:500]}")
        raise


def execute_tool(name, args):
    if name == "read_file":
        path = args.get("path", "")
        if not os.path.exists(path):
            return f"ERROR: File not found: {path}"
        try:
            with open(path, encoding="utf-8") as f:
                content = f.read()
            # Truncate very large files
            if len(content) > 50000:
                return content[:50000] + f"\n... (truncated, {len(content)} bytes total)"
            return content
        except Exception as e:
            return f"ERROR: {e}"

    elif name == "write_file":
        path = args.get("path", "")
        content = args.get("content", "")
        try:
            parent = os.path.dirname(path)
            if parent:
                os.makedirs(parent, exist_ok=True)
            with open(path, "w", encoding="utf-8") as f:
                f.write(content)
            return f"OK: wrote {len(content)} bytes to {path}"
        except Exception as e:
            return f"ERROR: {e}"

    elif name == "run_command":
        cmd = args.get("command", "")
        for pattern in BLOCKED_PATTERNS:
            if pattern in cmd:
                return f"BLOCKED: Destructive command not allowed: {cmd}"
        try:
            result = subprocess.run(
                cmd,
                shell=True,
                stdin=subprocess.DEVNULL,
                capture_output=True,
                text=True,
                timeout=CMD_TIMEOUT,
                cwd=os.environ.get("REPO_ROOT", "."),
            )
            output = ""
            if result.stdout:
                output += result.stdout
            if result.stderr:
                output += ("\n" if output else "") + "STDERR: " + result.stderr
            if result.returncode != 0:
                output += f"\nExit code: {result.returncode}"
            # Truncate long output
            if len(output) > 10000:
                output = output[:10000] + "\n... (truncated)"
            return output if output else "(no output)"
        except subprocess.TimeoutExpired:
            return f"ERROR: Command timed out after {CMD_TIMEOUT}s"
        except Exception as e:
            return f"ERROR: {e}"

    elif name == "list_files":
        path = args.get("path", ".")
        if not os.path.isdir(path):
            return f"ERROR: Not a directory: {path}"
        try:
            entries = sorted(os.listdir(path))
            result = []
            for entry in entries:
                full = os.path.join(path, entry)
                suffix = "/" if os.path.isdir(full) else ""
                result.append(f"{entry}{suffix}")
            return "\n".join(result) if result else "(empty directory)"
        except Exception as e:
            return f"ERROR: {e}"

    return f"ERROR: Unknown tool: {name}"


def run_agent(prompt):
    if not API_KEY:
        log("ERROR: GEMINI_API_KEY is not set")
        return 1

    contents = [{"role": "user", "parts": [{"text": prompt}]}]

    for turn in range(MAX_TURNS):
        log(f"turn {turn + 1}/{MAX_TURNS}")

        try:
            response = api_call(contents)
        except Exception as e:
            log(f"API call failed: {e}")
            return 1

        candidates = response.get("candidates", [])
        if not candidates:
            log("No candidates in response")
            # Check for prompt feedback (safety filters etc)
            feedback = response.get("promptFeedback", {})
            if feedback:
                log(f"Prompt feedback: {json.dumps(feedback)}")
            return 1

        candidate = candidates[0]
        finish_reason = candidate.get("finishReason", "")
        content = candidate.get("content", {})
        parts = content.get("parts", [])

        function_calls = [p for p in parts if "functionCall" in p]
        text_parts = [p for p in parts if "text" in p]

        # Print any text the model produces
        for part in text_parts:
            print(part["text"], flush=True)

        # If no function calls, the agent is done
        if not function_calls:
            log(f"done (finish_reason={finish_reason})")
            return 0

        # Add model response to conversation
        contents.append({"role": "model", "parts": parts})

        # Execute each function call
        tool_responses = []
        for fc in function_calls:
            call = fc["functionCall"]
            name = call["name"]
            args = call.get("args", {})

            # Log what we're doing (truncate long content)
            log_args = dict(args)
            if "content" in log_args and len(log_args["content"]) > 100:
                log_args["content"] = log_args["content"][:100] + "..."
            log(f"  {name}({json.dumps(log_args)})")

            result = execute_tool(name, args)

            tool_responses.append(
                {
                    "functionResponse": {
                        "name": name,
                        "response": {"result": result},
                    }
                }
            )

        contents.append({"role": "user", "parts": tool_responses})

    log(f"WARNING: reached max turns ({MAX_TURNS})")
    return 0


if __name__ == "__main__":
    prompt = sys.stdin.read()
    if not prompt.strip():
        log("ERROR: empty prompt on stdin")
        sys.exit(1)
    sys.exit(run_agent(prompt))
