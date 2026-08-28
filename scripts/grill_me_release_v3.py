#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]

SAFE_SCRIPTS = [
    "scripts/grill_me_hardening.py",
    "scripts/grill_me_logic_fixes.py",
    "scripts/grill_me_style_compat.py",
    "scripts/grill_me_case_continuation.py",
    "scripts/grill_me_held_candidates.py",
    "scripts/grill_me_context_disambiguation.py",
    "scripts/grill_me_margin_reproposal.py",
    "scripts/grill_me_top_candidate.py",
    "scripts/grill_me_context_linking.py",
    "scripts/grill_me_event_month_impact.py",
    "scripts/grill_me_future_month_plan.py",
    "scripts/grill_me_date_parsing.py",
    "scripts/grill_me_case_title_sync.py",
]

for relative in SAFE_SCRIPTS:
    path = ROOT / relative
    if path.exists():
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


# All calendar-affecting writes refresh recommendation and rebalance state.
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

# Candidate displays must not pretend a representative time is confirmed.
for path in ROOT.glob("Mira/**/*.swift"):
    text = path.read_text(encoding="utf-8")
    updated = text.replace("candidate.timeOfDay.title", "candidate.displayDescription")
    updated = updated.replace("slot.timeOfDay.title", "slot.displayDescription")
    if updated != text:
        path.write_text(updated, encoding="utf-8")

# Documentation indexes.
readme_path = ROOT / "README.md"
if readme_path.exists():
    readme = readme_path.read_text(encoding="utf-8")
    links = [
        "- [Grill-Me Q61〜Q82 実装対応表](docs/implementation-grill-me-q61-q82.md)",
        "- [生成画像スキン制作ロードマップ](docs/roadmap-generated-skins.md)",
    ]
    missing = [link for link in links if link not in readme]
    if missing:
        readme += "\n\n## Grill-Me 実装\n\n" + "\n".join(missing) + "\n"
        readme_path.write_text(readme, encoding="utf-8")

print("Complete Grill-Me release product tree finalized.")
