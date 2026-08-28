#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re
import runpy

ROOT = Path(__file__).resolve().parents[1]

for relative in [
    "scripts/mira_release_v6.py",
    "scripts/mira_release_v5.py",
    "scripts/grill_me_release_v4.py",
    "scripts/grill_me_release_v3.py",
]:
    path = ROOT / relative
    if path.exists():
        runpy.run_path(str(path), run_name="__main__")
        break

# Independently guarantee every custom test container includes the new models.
for path in ROOT.glob("MiraTests/**/*.swift"):
    text = path.read_text(encoding="utf-8")
    if ("ModelContainer" not in text and "Schema([" not in text) or "ConversationCaseEntity.self" in text:
        continue
    lines = text.splitlines()
    insertion = None
    for token in ("ImportantPersonEntity.self", "LoadRuleEntity.self", "PendingInvitationEntity.self"):
        for index, line in enumerate(lines):
            if token in line:
                insertion = index + 1
                break
        if insertion is not None:
            break
    if insertion is None:
        continue
    previous = lines[insertion - 1]
    indent = previous[:len(previous) - len(previous.lstrip())]
    if not previous.rstrip().endswith(","):
        lines[insertion - 1] = previous.rstrip() + ","
    lines[insertion:insertion] = [
        f"{indent}ConversationCaseEntity.self,",
        f"{indent}RebalanceProposalEntity.self,",
    ]
    path.write_text("\n".join(lines) + ("\n" if text.endswith("\n") else ""), encoding="utf-8")

# Final Swift regular-expression escape repair.
for path in ROOT.glob("Mira/**/*.swift"):
    text = path.read_text(encoding="utf-8")
    updated = re.sub(r"(?<!\\)\\([dsp])", r"\\\\\1", text)
    if updated != text:
        path.write_text(updated, encoding="utf-8")

# Fail before Xcode if a required accepted feature was somehow omitted.
required = {
    "Mira/Features/Conversation/MiraQuickInputBar.swift": ["この話について", "過去も検索"],
    "Mira/Features/Adjustments/SchedulingModeView.swift": ["おすすめをすべて外す", "いちばんおすすめ"],
    "Mira/App/MiraStore+Conversation.swift": ["enrichConversationInterpretation", "pendingChangePreview", "commitSchedulingDraft"],
    "Mira/App/MiraStore+ConversationContext.swift": ["夜を除外", "applySchedulingConstraints"],
    "Mira/Services/CaseSearchEngine.swift": ["includePast", "automaticCandidates"],
    "Mira/Services/ConversationAssistantService.swift": ["FoundationModelConversationInterpreter", "HybridDeclineDraftGenerator"],
    "Mira/App/MiraStore+MarginRecommendationStatus.swift": ["automaticMarginTargetsEnabled", "marginTargetChanges"],
    "Mira/Domain/MarginRecommendationEngine.swift": ["MarginRecommendationEngine", "RebalanceEngine"],
    "docs/roadmap-generated-skins.md": ["Codex", "後続フェーズ"],
}

missing = []
for relative, markers in required.items():
    path = ROOT / relative
    if not path.exists():
        missing.append(f"missing file: {relative}")
        continue
    content = path.read_text(encoding="utf-8")
    for marker in markers:
        if marker not in content:
            missing.append(f"{relative}: {marker}")

if missing:
    raise SystemExit("Required Grill-Me implementation missing:\n" + "\n".join(missing))

print("Stable release V7 finalization and acceptance guard completed.")
