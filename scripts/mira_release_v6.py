#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re
import runpy

ROOT = Path(__file__).resolve().parents[1]

for relative in ["scripts/mira_release_v5.py", "scripts/grill_me_test_schema.py"]:
    path = ROOT / relative
    if path.exists():
        runpy.run_path(str(path), run_name="__main__")

# Register new SwiftData models in every hand-built test schema/container, even
# when a fixture omits ImportantPersonEntity.
for path in ROOT.glob("MiraTests/**/*.swift"):
    text = path.read_text(encoding="utf-8")
    if "ModelContainer" not in text and "Schema([" not in text:
        continue
    if "ConversationCaseEntity.self" in text:
        continue

    lines = text.splitlines()
    insertion_index = None
    for index, line in enumerate(lines):
        if "ImportantPersonEntity.self" in line:
            insertion_index = index + 1
            break
    if insertion_index is None:
        for index, line in enumerate(lines):
            if "LoadRuleEntity.self" in line:
                insertion_index = index + 1
                break
    if insertion_index is None:
        continue

    previous = lines[insertion_index - 1]
    indent = previous[: len(previous) - len(previous.lstrip())]
    if not previous.rstrip().endswith(","):
        lines[insertion_index - 1] = previous.rstrip() + ","
    lines[insertion_index:insertion_index] = [
        f"{indent}ConversationCaseEntity.self,",
        f"{indent}RebalanceProposalEntity.self,",
    ]
    path.write_text("\n".join(lines) + ("\n" if text.endswith("\n") else ""), encoding="utf-8")

# Keep generated regular-expression literals valid after any optional patch
# script ran during this release.
for path in ROOT.glob("Mira/**/*.swift"):
    text = path.read_text(encoding="utf-8")
    updated = re.sub(r"(?<!\\)\\([dsp])", r"\\\\\1", text)
    if updated != text:
        path.write_text(updated, encoding="utf-8")

# Avoid an optional/numeric inference edge in a unit assertion.
for path in ROOT.glob("MiraTests/**/*.swift"):
    text = path.read_text(encoding="utf-8")
    updated = text.replace(
        "XCTAssertEqual(decoded.recommendationScore, 98)",
        "XCTAssertEqual(decoded.recommendationScore, 98.0)",
    )
    if updated != text:
        path.write_text(updated, encoding="utf-8")

print("Mira release V6 finalized source and every test schema.")
