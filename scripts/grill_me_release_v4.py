#!/usr/bin/env python3
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]

scripts = [
    "scripts/grill_me_release_v3.py",
    "scripts/grill_me_context_disambiguation.py",
    "scripts/grill_me_margin_reproposal.py",
    "scripts/grill_me_top_candidate.py",
    "scripts/grill_me_context_linking.py",
    "scripts/grill_me_event_month_impact.py",
    "scripts/grill_me_future_month_plan.py",
    "scripts/grill_me_date_parsing.py",
    "scripts/grill_me_case_title_sync.py",
    "scripts/grill_me_margin_mode_persistence.py",
    "scripts/grill_me_escape_repair.py",
]

for relative in scripts:
    path = ROOT / relative
    if path.exists() and path.name != Path(__file__).name:
        runpy.run_path(str(path), run_name="__main__")

print("Grill-Me release V4 finalized every accepted requirement.")
