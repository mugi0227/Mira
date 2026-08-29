#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def run_existing(script: str) -> None:
    path = ROOT / script
    if path.exists():
        subprocess.run(["python3", str(path)], cwd=ROOT, check=True)


def replace(path: str, old: str, new: str) -> None:
    target = ROOT / path
    if not target.exists():
        return
    text = target.read_text(encoding="utf-8")
    if new in text or old not in text:
        return
    target.write_text(text.replace(old, new), encoding="utf-8")


# Reuse the previous implementation work, but materialize its idempotent patches
# before the compiler sees the source tree.
run_existing("scripts/grill_me_hardening.py")
run_existing("scripts/grill_me_logic_fixes.py")

# Cross-file store extensions need to mutate this loading state.
replace(
    "Mira/App/MiraStore.swift",
    "private(set) var isInterpretingConversation = false",
    "var isInterpretingConversation = false",
)

# Avoid an infinite size proposal in the custom wrapping layout.
replace(
    "Mira/DesignSystem/FlowLayout.swift",
    "let maxWidth = proposal.width ?? .infinity",
    "let maxWidth = proposal.width ?? 10_000",
)
replace(
    "Mira/DesignSystem/FlowLayout.swift",
    "proposal: ProposedViewSize(size)",
    "proposal: ProposedViewSize(width: size.width, height: size.height)",
)

# SwiftUI ForEach is more stable with enum IDs than tuple key paths.
replace(
    "Mira/Features/Conversation/ConversationResultSheets.swift",
    "ForEach(sortedDeficits, id: \\.0) { kind, deficit in",
    "ForEach(sortedDeficitKinds) { kind in",
)
replace(
    "Mira/Features/Conversation/ConversationResultSheets.swift",
    "\\(deficit)枠必要",
    "\\(preview.impact.projectedGoalDeficits[kind, default: 0])枠必要",
)
replace(
    "Mira/Features/Conversation/ConversationResultSheets.swift",
    "\\(deficit)枠不足",
    "\\(preview.impact.projectedGoalDeficits[kind, default: 0])枠不足",
)

print("Verified build preparation complete.")
