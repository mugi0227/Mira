#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

for path in ROOT.glob("MiraTests/**/*.swift"):
    text = path.read_text(encoding="utf-8")
    if "Schema([" not in text or "ImportantPersonEntity.self" not in text:
        continue
    if "ConversationCaseEntity.self" in text:
        continue
    text = text.replace(
        "            ImportantPersonEntity.self\n",
        "            ImportantPersonEntity.self,\n            ConversationCaseEntity.self,\n            RebalanceProposalEntity.self\n",
        1,
    )
    text = text.replace(
        "            ImportantPersonEntity.self,\n        ])",
        "            ImportantPersonEntity.self,\n            ConversationCaseEntity.self,\n            RebalanceProposalEntity.self\n        ])",
        1,
    )
    path.write_text(text, encoding="utf-8")

print("Test SwiftData schemas include conversational models.")
