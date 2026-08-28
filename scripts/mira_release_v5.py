#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re
import runpy

ROOT = Path(__file__).resolve().parents[1]

# Apply any still-available idempotent bundle first. Older successful cleanup may
# have removed it only after applying it, which is also safe.
for relative in [
    "scripts/grill_me_release_v4.py",
    "scripts/grill_me_release_v3.py",
    "scripts/grill_me_hardening.py",
    "scripts/grill_me_logic_fixes.py",
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
]:
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


# Automatic/manual margin planning mode is persisted even if its temporary
# patch workflow was cleaned before running.
settings_model = "Mira/Data/PersistenceModels.swift"
text = read(settings_model)
if "var automaticMarginTargetsEnabled: Bool?" not in text:
    text = text.replace(
        "    var marginComfortRaw: String?\n    var createdAt: Date\n",
        "    var marginComfortRaw: String?\n    var automaticMarginTargetsEnabled: Bool?\n    var createdAt: Date\n",
        1,
    )
    text = text.replace(
        '''        demoModeEnabled: Bool = true,
        marginComfortRaw: String = MarginComfortLevel.standard.rawValue
''',
        '''        demoModeEnabled: Bool = true,
        marginComfortRaw: String = MarginComfortLevel.standard.rawValue,
        automaticMarginTargetsEnabled: Bool = true
''',
        1,
    )
    text = text.replace(
        '''        self.marginComfortRaw = marginComfortRaw
        self.createdAt = .now
''',
        '''        self.marginComfortRaw = marginComfortRaw
        self.automaticMarginTargetsEnabled = automaticMarginTargetsEnabled
        self.createdAt = .now
''',
        1,
    )
write(settings_model, text)

store_path = "Mira/App/MiraStore.swift"
text = read(store_path)
if "var automaticMarginTargetsEnabled = true" not in text:
    text = text.replace(
        "    var marginComfortLevel: MarginComfortLevel = .standard\n",
        "    var marginComfortLevel: MarginComfortLevel = .standard\n    var automaticMarginTargetsEnabled = true\n",
        1,
    )
write(store_path, text)

helpers_path = "Mira/App/MiraStore+Helpers.swift"
text = read(helpers_path)
if "automaticMarginTargetsEnabled = settingsEntity.automaticMarginTargetsEnabled" not in text:
    text = text.replace(
        '''        marginComfortLevel = MarginComfortLevel(rawValue: settingsEntity.marginComfortRaw ?? "") ?? .standard
''',
        '''        marginComfortLevel = MarginComfortLevel(rawValue: settingsEntity.marginComfortRaw ?? "") ?? .standard
        automaticMarginTargetsEnabled = settingsEntity.automaticMarginTargetsEnabled ?? true
''',
        1,
    )
write(helpers_path, text)

availability_path = "Mira/App/MiraStore+Availability.swift"
text = read(availability_path)
if "automaticMarginTargetsEnabled = useRecommendedTargets" not in text:
    text = text.replace(
        '''            onboardingCompleted = true
            marginComfortLevel = marginComfort
            settingsEntity?.onboardingCompleted = true
            settingsEntity?.marginComfortRaw = marginComfort.rawValue
''',
        '''            onboardingCompleted = true
            marginComfortLevel = marginComfort
            automaticMarginTargetsEnabled = useRecommendedTargets
            settingsEntity?.onboardingCompleted = true
            settingsEntity?.marginComfortRaw = marginComfort.rawValue
            settingsEntity?.automaticMarginTargetsEnabled = useRecommendedTargets
''',
        1,
    )
write(availability_path, text)

status_path = "Mira/App/MiraStore+MarginRecommendationStatus.swift"
if (ROOT / status_path).exists():
    text = read(status_path)
    if "guard automaticMarginTargetsEnabled," not in text:
        text = text.replace(
            '''    var marginTargetChanges: [MarginTargetChange] {
        guard let recommendation = currentMarginRecommendation,
''',
            '''    var marginTargetChanges: [MarginTargetChange] {
        guard automaticMarginTargetsEnabled,
              let recommendation = currentMarginRecommendation,
''',
            1,
        )
    write(status_path, text)

settings_path = "Mira/App/MiraStore+Settings.swift"
text = read(settings_path)
if "settingsEntity?.automaticMarginTargetsEnabled = true" not in text:
    text = text.replace(
        '''        marginComfortLevel = level
        settingsEntity?.marginComfortRaw = level.rawValue
''',
        '''        marginComfortLevel = level
        automaticMarginTargetsEnabled = true
        settingsEntity?.marginComfortRaw = level.rawValue
        settingsEntity?.automaticMarginTargetsEnabled = true
''',
        1,
    )
    text = text.replace(
        '''            settingsEntity?.marginComfortRaw = MarginComfortLevel.standard.rawValue
''',
        '''            settingsEntity?.marginComfortRaw = MarginComfortLevel.standard.rawValue
            settingsEntity?.automaticMarginTargetsEnabled = true
''',
        1,
    )
    text = text.replace(
        '''            marginComfortLevel = .standard
''',
        '''            marginComfortLevel = .standard
            automaticMarginTargetsEnabled = true
''',
        1,
    )
write(settings_path, text)

planning_path = "Mira/App/MiraStore+Planning.swift"
text = read(planning_path)
if "settingsEntity?.automaticMarginTargetsEnabled = false" not in text:
    text = text.replace(
        '''                entity.targetCount = max(0, target)
                entity.isEnabled = target > 0
                try context.save()
''',
        '''                entity.targetCount = max(0, target)
                entity.isEnabled = target > 0
                automaticMarginTargetsEnabled = false
                settingsEntity?.automaticMarginTargetsEnabled = false
                settingsEntity?.updatedAt = .now
                try context.save()
''',
        1,
    )
write(planning_path, text)

# Repair generated Swift regex escapes. Already-correct double escapes are not
# touched.
for path in ROOT.glob("Mira/**/*.swift"):
    text = path.read_text(encoding="utf-8")
    updated = re.sub(r"(?<!\\)\\([dsp])", r"\\\\\1", text)
    if updated != text:
        path.write_text(updated, encoding="utf-8")

# Required documentation remains discoverable.
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

print("Mira V5 self-contained finalization complete.")
