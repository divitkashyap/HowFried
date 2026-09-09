#!/usr/bin/env python3
"""Print a reviewable additive hook snippet; never modify provider files."""
import json
import pathlib
import shlex
import sys

if len(sys.argv) != 3 or sys.argv[2] not in ("claude", "codex"):
    raise SystemExit("Usage: python3 scripts/hook_snippet.py /absolute/HowFried.app claude|codex")
bundle = pathlib.Path(sys.argv[1])
if not bundle.is_absolute():
    raise SystemExit("Use an absolute app path.")
executable = bundle / "Contents" / "MacOS" / "howfried-hook"
if not executable.is_file():
    raise SystemExit("Hook executable not found in that bundle.")
print(json.dumps({"hooks": {"UserPromptSubmit": [{"hooks": [{
    "type": "command", "command": shlex.quote(str(executable)) + " " + sys.argv[2], "timeout": 2
}]}]}}, indent=2))
