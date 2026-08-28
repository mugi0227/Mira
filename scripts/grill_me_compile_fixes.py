#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def patch(path: str, old: str, new: str, required: bool = False) -> None:
    target = ROOT / path
    text = target.read_text(encoding="utf-8")
    if new in text:
        return
    if old not in text:
        if required:
            raise RuntimeError(f"Missing expected block in {path}: {old[:120]!r}")
        return
    target.write_text(text.replace(old, new, 1), encoding="utf-8")


# Apply the main idempotent finalization first when this workflow runs alone.
exec((ROOT / "scripts/finalize_grill_me.py").read_text(encoding="utf-8"), {"__file__": str(ROOT / "scripts/finalize_grill_me.py"), "__name__": "__main__"})

# Setter is used by an extension in another source file.
patch(
    "Mira/App/MiraStore.swift",
    "    private(set) var isInterpretingConversation = false\n",
    "    var isInterpretingConversation = false\n",
    required=True,
)

# Moving to a month outside the original range should search that month rather
# than construct an invalid DateInterval.
patch(
    "Mira/App/MiraStore+Conversation.swift",
    '''        if let month {
            draft.month = month
            let key = MonthKey(date: month)
            draft.dateRangeStart = max(draft.dateRangeStart, key.firstDay)
            draft.dateRangeEnd = min(draft.dateRangeEnd, key.interval.end.addingTimeInterval(-1))
        }
''',
    '''        if let month {
            draft.month = month
            let key = MonthKey(date: month)
            let monthEnd = key.interval.end.addingTimeInterval(-1)
            let intersectsOriginalRange = draft.dateRangeStart <= monthEnd && draft.dateRangeEnd >= key.firstDay
            if intersectsOriginalRange {
                draft.dateRangeStart = max(draft.dateRangeStart, key.firstDay)
                draft.dateRangeEnd = min(draft.dateRangeEnd, monthEnd)
            } else {
                draft.dateRangeStart = key.firstDay
                draft.dateRangeEnd = monthEnd
            }
        }
''',
    required=True,
)

# The UI-test reset flag should make runs deterministic without affecting users.
patch(
    "Mira/App/MiraStore.swift",
    '''            try DemoSeeder.seedBaseline(in: context, clock: clock)
            try refresh()
''',
    '''            if ProcessInfo.processInfo.arguments.contains("-reset-demo") {
                try context.delete(model: CalendarItemEntity.self)
                try context.delete(model: MarginGoalEntity.self)
                try context.delete(model: AdjustmentEntity.self)
                try context.delete(model: PendingInvitationEntity.self)
                try context.delete(model: LoadRuleEntity.self)
                try context.delete(model: BaseRuleEntity.self)
                try context.delete(model: ConversationCaseEntity.self)
                try context.delete(model: RebalanceProposalEntity.self)
                settingsEntity?.onboardingCompleted = false
                try context.save()
                onboardingCompleted = false
            }
            try DemoSeeder.seedBaseline(in: context, clock: clock)
            try refresh()
''',
    required=True,
)

# Use a safe finite width when the wrapping layout is proposed without one.
patch(
    "Mira/DesignSystem/FlowLayout.swift",
    "        let maxWidth = proposal.width ?? .infinity\n",
    "        let maxWidth = proposal.width ?? 10_000\n",
)

print("Compile and state-transition fixups applied.")
