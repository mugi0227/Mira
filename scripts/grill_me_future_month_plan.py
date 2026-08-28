#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "Mira/App/MiraStore+Conversation.swift"
text = PATH.read_text(encoding="utf-8")

old = '''        let start = interpretation.dateRangeStart ?? interpretation.candidateDates.min() ?? defaultRange.start
        let end = interpretation.dateRangeEnd ?? interpretation.candidateDates.max() ?? defaultRange.end
        var draft = SchedulingDraft(
'''
new = '''        let start = interpretation.dateRangeStart ?? interpretation.candidateDates.min() ?? defaultRange.start
        let end = interpretation.dateRangeEnd ?? interpretation.candidateDates.max() ?? defaultRange.end
        ensurePlan(for: MonthKey(date: start).firstDay)
        var draft = SchedulingDraft(
'''
if old in text:
    text = text.replace(old, new, 1)

old = '''        var event = await prepareEvent(
            title: caseEntity.title,
'''
new = '''        ensurePlan(for: MonthKey(date: start).firstDay)
        var event = await prepareEvent(
            title: caseEntity.title,
'''
# Only the occurrence inside makeEventCreationPreview follows the start/end
# setup and is safe to patch from the end of the file.
method = text.find("    private func makeEventCreationPreview(")
if method >= 0:
    position = text.find(old, method)
    if position >= 0 and "ensurePlan(for: MonthKey(date: start).firstDay)" not in text[method:position]:
        text = text[:position] + new + text[position + len(old):]

PATH.write_text(text, encoding="utf-8")
print("Future month plans are ensured before conversational scheduling.")
