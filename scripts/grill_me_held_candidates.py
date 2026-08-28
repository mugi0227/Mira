#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def rw(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def save(path: str, text: str) -> None:
    (ROOT / path).write_text(text, encoding="utf-8")


# Held slots include sent adjustments and invitations under consideration.
path = "Mira/App/MiraStore+Adjustments.swift"
text = rw(path)
old = '''    func heldCandidates(excluding sessionID: UUID? = nil) -> [CandidateSlotSnapshot] {
        adjustments
            .filter { $0.id != sessionID && ($0.status == .draft || $0.status == .waiting) }
            .flatMap(\\.candidates)
            .filter { $0.status == .held }
    }
'''
new = '''    func heldCandidates(
        excluding sessionID: UUID? = nil,
        invitationID: UUID? = nil
    ) -> [CandidateSlotSnapshot] {
        let adjustmentSlots = adjustments
            .filter { $0.id != sessionID && ($0.status == .draft || $0.status == .waiting) }
            .flatMap(\\.candidates)
            .filter { $0.status == .held }
        let invitationSlots = pendingInvitations
            .filter {
                $0.id != invitationID &&
                ($0.status == .considering || $0.status == .adjustment)
            }
            .flatMap(\\.candidates)
            .filter { $0.status == .held }
        return adjustmentSlots + invitationSlots
    }
'''
if old in text:
    text = text.replace(old, new, 1)
save(path, text)

# Event entry should use the common held-slot source.
path = "Mira/App/MiraStore+EventEntry.swift"
text = rw(path)
old = '''        let heldCandidates = adjustments
            .filter { $0.status == .draft || $0.status == .waiting }
            .flatMap(\\.candidates)

        return ConflictEngine(calendar: .mira).conflicts(
'''
new = '''        let heldCandidates = heldCandidates()

        return ConflictEngine(calendar: .mira).conflicts(
'''
if old in text:
    text = text.replace(old, new, 1)
save(path, text)

# Candidate recommendation excludes the case currently being edited.
path = "Mira/App/MiraStore+Conversation.swift"
text = rw(path)
old = '''        let held = adjustments
            .filter { $0.status == .draft || $0.status == .waiting }
            .flatMap(\\.candidates)
        let range = DateInterval(start: draft.dateRangeStart, end: draft.dateRangeEnd)
'''
new = '''        let caseState = conversationCase(id: draft.conversationCaseID)?.state
        let held = heldCandidates(
            excluding: caseState?.relatedAdjustmentID,
            invitationID: caseState?.relatedInvitationID
        )
        let range = DateInterval(start: draft.dateRangeStart, end: draft.dateRangeEnd)
'''
if old in text:
    text = text.replace(old, new, 1)

# Persist the latest explicit constraints into the canonical case state.
old = '''        state.durationBucket = duration
        state.allowedTimeBands = bands
        state.lastIntent = interpretation.intent
'''
new = '''        state.durationBucket = duration
        state.allowedTimeBands = bands
        state.explicitConstraints = interpretation.explicitConstraints
        state.lastIntent = interpretation.intent
'''
if old in text:
    text = text.replace(old, new, 1)
save(path, text)

# Alternative scheduling uses the same held-slot source and excludes its case.
path = "Mira/App/MiraStore+ConversationAlternatives.swift"
text = rw(path)
old = '''        let held = adjustments
            .filter { $0.status == .draft || $0.status == .waiting }
            .flatMap(\\.candidates)
        let recommendations = schedulingRecommendationEngine.recommendations(
'''
new = '''        let state = caseEntity?.state
        let held = heldCandidates(
            excluding: state?.relatedAdjustmentID,
            invitationID: state?.relatedInvitationID
        )
        let recommendations = schedulingRecommendationEngine.recommendations(
'''
if old in text:
    text = text.replace(old, new, 1)
save(path, text)

# Weekday exclusions retain the existing date range rather than being treated
# as a new positive date request.
path = "Mira/App/MiraStore+ConversationContext.swift"
text = rw(path)
old = '''        return ["月曜", "火曜", "水曜", "木曜", "金曜", "土曜", "日曜"].contains(where: text.contains)
'''
new = '''        let exclusionWords = ["外して", "なし", "無理", "除外"]
        if exclusionWords.contains(where: text.contains) { return false }
        return ["月曜", "火曜", "水曜", "木曜", "金曜", "土曜", "日曜"].contains(where: text.contains)
'''
if old in text:
    text = text.replace(old, new, 1)
save(path, text)

print("Held-candidate and continuation state fixes applied.")
