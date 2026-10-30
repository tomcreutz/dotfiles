#!/usr/bin/env python3
"""PreToolUse guardrail: block Claude from touching environment files with secrets.

Mirrors the "project-env-files" rule from ~/.pi/agent/extensions/guardrails.json:
  - blocked:  *.env  (e.g. .env, prod.env) and .env.*  (e.g. .env.local, .env.production)
  - allowed:  example / sample / test variants
  - onlyIfExists: a path is only blocked if it actually exists on disk

Covers Read, Edit, Write, MultiEdit, NotebookEdit, Grep and Bash. Bash detection is
best-effort (it scans the command text for env-file paths), not a sandbox.
"""

from __future__ import annotations

import fnmatch
import glob
import json
import os
import re
import sys

BLOCK_PATTERNS = ["*.env", ".env.*"]
ALLOW_PATTERNS = [
    "*.env.example",
    "*.env.sample",
    "*.env.test",
    "*.example.env",
    "*.sample.env",
    "*.test.env",
]
ONLY_IF_EXISTS = True
BLOCK_MESSAGE = (
    "Accessing {file} is not allowed because it may contain local secrets. "
    "Example, sample, and test environment files remain accessible."
)

# Candidate path-like tokens in a shell command that mention ".env".
BASH_TOKEN_RE = re.compile(r"""[^\s'"`;|&<>(){}=,]*\.env[^\s'"`;|&<>(){}=,]*""")


def is_protected_name(path: str) -> bool:
    name = os.path.basename(path.rstrip("/"))
    if not any(fnmatch.fnmatchcase(name, p) for p in BLOCK_PATTERNS):
        return False
    return not any(fnmatch.fnmatchcase(name, p) for p in ALLOW_PATTERNS)


def resolve(path: str, cwd: str) -> str:
    path = os.path.expandvars(os.path.expanduser(path))
    return path if os.path.isabs(path) else os.path.join(cwd, path)


def blocked_path(path: str | None, cwd: str) -> str | None:
    """Return the offending path if `path` points at a protected env file."""
    if not path:
        return None
    full = resolve(path, cwd)
    if glob.has_magic(full):
        hits = [m for m in glob.glob(full, include_hidden=True) if is_protected_name(m)]
        return hits[0] if hits else None
    if not is_protected_name(full):
        return None
    if ONLY_IF_EXISTS and not os.path.exists(full):
        return None
    return path


def check(tool: str, tool_input: dict, cwd: str) -> str | None:
    if tool in ("Read", "Edit", "Write", "MultiEdit"):
        return blocked_path(tool_input.get("file_path"), cwd)
    if tool == "NotebookEdit":
        return blocked_path(tool_input.get("notebook_path"), cwd)
    if tool == "Grep":
        hit = blocked_path(tool_input.get("path"), cwd)
        if hit:
            return hit
        # A glob filter that targets env files, e.g. glob="*.env" or ".env*".
        pattern = os.path.basename(tool_input.get("glob") or "")
        if pattern and any(
            fnmatch.fnmatchcase(sample, pattern) and is_protected_name(sample)
            for sample in (".env", ".env.local", "prod.env")
        ):
            return pattern
        return None
    if tool == "Bash":
        command = tool_input.get("command", "")
        for token in BASH_TOKEN_RE.findall(command):
            hit = blocked_path(token, cwd)
            if hit:
                return hit
    return None


def main() -> None:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        return
    cwd = payload.get("cwd") or os.getcwd()
    hit = check(payload.get("tool_name", ""), payload.get("tool_input") or {}, cwd)
    if hit:
        json.dump(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": BLOCK_MESSAGE.format(file=hit),
                }
            },
            sys.stdout,
        )


if __name__ == "__main__":
    main()
