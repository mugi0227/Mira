#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]

# Every prior patch script is idempotent. If cleanup already removed one, its
# changes were committed before removal; if it still exists, apply it again.
for relative in [
    "scripts/finalize_grill_me.py",
    "scripts/grill_me_compile_fixes.py",
    "scripts/grill_me_hardening.py",
    "scripts/grill_me_logic_fixes.py",
    "scripts/grill_me_style_compat.py",
    "scripts/grill_me_case_continuation.py",
    "scripts/grill_me_held_candidates.py",
]:
    path = ROOT / relative
    if path.exists() and path.name != Path(__file__).name:
        runpy.run_path(str(path), run_name="__main__")


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write(path: str, text: str) -> None:
    (ROOT / path).write_text(text, encoding="utf-8")


def replace_once(path: str, old: str, new: str) -> None:
    text = read(path)
    if new in text:
        return
    if old in text:
        write(path, text.replace(old, new, 1))


# Persist constraints whenever a scheduling draft is opened.
replace_once(
    "Mira/App/MiraStore+Conversation.swift",
    '''        state.durationBucket = duration
        state.allowedTimeBands = bands
        state.lastIntent = interpretation.intent
''',
    '''        state.durationBucket = duration
        state.allowedTimeBands = bands
        state.explicitConstraints = interpretation.explicitConstraints
        state.lastIntent = interpretation.intent
''',
)

# Auto placement and direct margin changes refresh the silent balance proposal.
replace_once(
    "Mira/App/MiraStore+Planning.swift",
    '''            try context.save()
            try refresh()
            toast = proposal.unmetGoals.isEmpty
''',
    '''            try context.save()
            try refresh()
            updateMarginRecommendation(for: month)
            recalculateBalance(for: month)
            toast = proposal.unmetGoals.isEmpty
''',
)
replace_once(
    "Mira/App/MiraStore+Planning.swift",
    '''        context.insert(CalendarItemEntity(snapshot: snapshot))
        try? context.save()
        try? refresh()
''',
    '''        context.insert(CalendarItemEntity(snapshot: snapshot))
        try? context.save()
        try? refresh()
        updateMarginRecommendation(for: date)
        recalculateBalance(for: date)
''',
)
replace_once(
    "Mira/App/MiraStore+Planning.swift",
    '''                try context.save()
                try refresh()
            }
        } catch {
            toast = "目標を変更できませんでした"
''',
    '''                try context.save()
                try refresh()
                updateMarginRecommendation(for: key.firstDay)
                recalculateBalance(for: key.firstDay)
            }
        } catch {
            toast = "目標を変更できませんでした"
''',
)

# Base-rule edits affect recommendations immediately but never move data without
# an explicit apply action.
replace_once(
    "Mira/App/MiraStore+Availability.swift",
    '''            try replaceBaseRules(with: rules)
            try context.save()
            toast = rules.isEmpty
''',
    '''            try replaceBaseRules(with: rules)
            try context.save()
            try refresh()
            updateMarginRecommendation(for: selectedMonth)
            recalculateBalance(for: selectedMonth)
            toast = rules.isEmpty
''',
)

# Existing candidates show coarse time honestly instead of representative fake
# precision in shared generated messages where the helper is available.
for relative in [
    "Mira/Features/Adjustments/AdjustmentDetailSheet.swift",
    "Mira/Features/Adjustments/PendingInvitationDetailSheet.swift",
]:
    path = ROOT / relative
    if not path.exists():
        continue
    text = path.read_text(encoding="utf-8")
    text = text.replace(
        'candidate.timeOfDay.title',
        'candidate.exactTimeKnown == false ? candidate.displayDescription : candidate.timeOfDay.title',
    )
    path.write_text(text, encoding="utf-8")

# Product README points to the implementation map and deferred skin roadmap.
readme = ROOT / "README.md"
if readme.exists():
    text = readme.read_text(encoding="utf-8")
    links = [
        "- [Grill-Me Q61〜Q82 実装対応表](docs/implementation-grill-me-q61-q82.md)",
        "- [生成画像スキン制作ロードマップ](docs/roadmap-generated-skins.md)",
    ]
    missing = [link for link in links if link not in text]
    if missing:
        text += "\n\n## Grill-Me 実装\n\n" + "\n".join(missing) + "\n"
        readme.write_text(text, encoding="utf-8")

print("Authoritative Grill-Me v2 product finalization complete.")
