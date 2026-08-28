#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "Mira/App/MiraStore+Planning.swift"
text = PATH.read_text(encoding="utf-8")
old = '''    func previewImpact(for event: CalendarItemSnapshot) -> ScheduleImpact {
        let overlapping = items.filter { $0.kind == .margin && $0.occupiedInterval.intersects(event.occupiedInterval) }
        let first = overlapping.first
        let otherMargins = items.filter { $0.kind == .margin }
        let candidates: [Date]
        if let first {
            candidates = scheduler.relocationCandidates(
                for: first,
                month: selectedMonth,
                events: items.filter { $0.kind != .margin } + [event],
                otherMargins: otherMargins,
                baseRules: fetchBaseRules()
            )
        } else {
            candidates = []
        }
        return protectionEngine.analyze(
            proposedEvent: event,
            month: selectedMonth,
            items: items,
            goals: currentMonthGoals,
            relocationCandidates: candidates
        )
    }
'''
new = '''    func previewImpact(for event: CalendarItemSnapshot) -> ScheduleImpact {
        let eventMonth = MonthKey(date: event.startDate)
        let eventMonthGoals = goals.filter {
            $0.year == eventMonth.year && $0.month == eventMonth.month
        }
        let overlapping = items.filter {
            $0.kind == .margin && $0.occupiedInterval.intersects(event.occupiedInterval)
        }
        let first = overlapping.first
        let otherMargins = items.filter { $0.kind == .margin }
        let candidates: [Date]
        if let first {
            candidates = scheduler.relocationCandidates(
                for: first,
                month: eventMonth.firstDay,
                events: items.filter { $0.kind != .margin } + [event],
                otherMargins: otherMargins,
                baseRules: fetchBaseRules()
            )
        } else {
            candidates = []
        }
        return protectionEngine.analyze(
            proposedEvent: event,
            month: eventMonth.firstDay,
            items: items,
            goals: eventMonthGoals,
            relocationCandidates: candidates
        )
    }
'''
if old in text:
    text = text.replace(old, new, 1)
PATH.write_text(text, encoding="utf-8")
print("Event impact now uses the event month.")
