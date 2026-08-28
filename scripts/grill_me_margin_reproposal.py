#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

path = ROOT / "Mira/App/MiraStore.swift"
text = path.read_text(encoding="utf-8")
old = '''    var currentAssistantMessage: AssistantMessage {
        if let proposal = activeRebalanceProposal,
'''
new = '''    var currentAssistantMessage: AssistantMessage {
        if hasMarginTargetRecommendationChange {
            return AssistantMessage(
                title: "必要な余白量を計算し直したにゃ",
                body: marginTargetChangeMessage,
                mood: .thinking,
                severity: 2,
                actionTitle: "おすすめ余白を見る"
            )
        }
        if let proposal = activeRebalanceProposal,
'''
if old in text:
    text = text.replace(old, new, 1)
path.write_text(text, encoding="utf-8")

path = ROOT / "Mira/Features/Home/HomeView.swift"
text = path.read_text(encoding="utf-8")
old = '''                    AssistantCard(message: store.currentAssistantMessage, palette: palette) {
                        if store.activeRebalanceProposal != nil {
                            showRebalanceSheet = true
                        } else {
                            store.autoPlaceMargins(for: store.selectedMonth)
                        }
                    }
'''
new = '''                    AssistantCard(message: store.currentAssistantMessage, palette: palette) {
                        if store.hasMarginTargetRecommendationChange {
                            showMarginComfortSheet = true
                        } else if store.activeRebalanceProposal != nil {
                            showRebalanceSheet = true
                        } else {
                            store.autoPlaceMargins(for: store.selectedMonth)
                        }
                    }
'''
if old in text:
    text = text.replace(old, new, 1)
path.write_text(text, encoding="utf-8")
print("Margin target reproposal wired.")
