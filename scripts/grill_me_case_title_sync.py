#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "Mira/App/MiraStore+Conversation.swift"
text = PATH.read_text(encoding="utf-8")

old = '''        let candidates = selected.map { recommendation -> CandidateSlotSnapshot in
'''
new = '''        let cleanedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty else {
            toast = "予定タイトルを入れてにゃ"
            return
        }

        let candidates = selected.map { recommendation -> CandidateSlotSnapshot in
'''
if old in text and "let cleanedTitle = draft.title" not in text:
    text = text.replace(old, new, 1)

text = text.replace("let message = DemoSeeder.message(title: draft.title, candidates: candidates)", "let message = DemoSeeder.message(title: cleanedTitle, candidates: candidates)", 1)

old = '''        let caseEntity = conversationCase(id: draft.conversationCaseID)

        if activeSchedulingIntent == .checkInvitation {
'''
new = '''        let caseEntity = conversationCase(id: draft.conversationCaseID)
        if let caseEntity {
            caseEntity.title = cleanedTitle
            var state = caseEntity.state
            state.person = draft.person
            caseEntity.state = state
        }

        if activeSchedulingIntent == .checkInvitation {
'''
if old in text:
    text = text.replace(old, new, 1)

# Persist the cleaned title in both new and existing records.
text = text.replace("invitation.title = draft.title", "invitation.title = cleanedTitle")
text = text.replace("title: draft.title,\n                    contactName: draft.person,\n                    status: .considering", "title: cleanedTitle,\n                    contactName: draft.person,\n                    status: .considering")
text = text.replace("adjustment.title = draft.title", "adjustment.title = cleanedTitle")
text = text.replace("title: draft.title,\n                    contactName: draft.person,\n                    status: .waiting", "title: cleanedTitle,\n                    contactName: draft.person,\n                    status: .waiting")

PATH.write_text(text, encoding="utf-8")
print("Canonical scheduling title/person synchronization applied.")
