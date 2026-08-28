#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
changed = []

for path in ROOT.glob("Mira/**/*.swift"):
    text = path.read_text(encoding="utf-8")
    # Swift string literals need two source backslashes for regular-expression
    # escapes. Match only a genuinely single backslash so already-correct
    # sequences remain untouched.
    updated = re.sub(r"(?<!\\)\\([dsp])", r"\\\\\1", text)
    if updated != text:
        path.write_text(updated, encoding="utf-8")
        changed.append(str(path.relative_to(ROOT)))

print("Repaired Swift regex escaping in:", ", ".join(changed) if changed else "none")
