#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FILES = [
    "Mira/Features/Conversation/MiraQuickInputBar.swift",
    "Mira/Features/Conversation/ConversationResultSheets.swift",
    "Mira/Features/Adjustments/SchedulingModeView.swift",
]

for relative in FILES:
    path = ROOT / relative
    text = path.read_text(encoding="utf-8")
    text = text.replace("palette.elevatedBackground", "palette.surface")
    text = text.replace("MiraRadius.large", "MiraRadius.medium")
    path.write_text(text, encoding="utf-8")

print("Design-token compatibility applied.")
