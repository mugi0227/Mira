#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# SwiftData setting: optional for lightweight migration of existing demo stores.
path = ROOT / "Mira/Data/PersistenceModels.swift"
text = path.read_text(encoding="utf-8")
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
path.write_text(text, encoding="utf-8")

# Store state and bootstrap application.
path = ROOT / "Mira/App/MiraStore.swift"
text = path.read_text(encoding="utf-8")
text = text.replace(
    "    var marginComfortLevel: MarginComfortLevel = .standard\n",
    "    var marginComfortLevel: MarginComfortLevel = .standard\n    var automaticMarginTargetsEnabled = true\n",
    1,
)
path.write_text(text, encoding="utf-8")

path = ROOT / "Mira/App/MiraStore+Helpers.swift"
text = path.read_text(encoding="utf-8")
text = text.replace(
    '''        marginComfortLevel = MarginComfortLevel(rawValue: settingsEntity.marginComfortRaw ?? "") ?? .standard
''',
    '''        marginComfortLevel = MarginComfortLevel(rawValue: settingsEntity.marginComfortRaw ?? "") ?? .standard
        automaticMarginTargetsEnabled = settingsEntity.automaticMarginTargetsEnabled ?? true
''',
    1,
)
path.write_text(text, encoding="utf-8")

# Onboarding records the chosen mode.
path = ROOT / "Mira/App/MiraStore+Availability.swift"
text = path.read_text(encoding="utf-8")
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
path.write_text(text, encoding="utf-8")

# Choosing a comfort level is an explicit opt-in to automatic targets.
path = ROOT / "Mira/App/MiraStore+Settings.swift"
text = path.read_text(encoding="utf-8")
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
path.write_text(text, encoding="utf-8")

# Automatic target-change cards are hidden in manual mode.
path = ROOT / "Mira/App/MiraStore+MarginRecommendationStatus.swift"
text = path.read_text(encoding="utf-8")
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
path.write_text(text, encoding="utf-8")

# Direct manual target edits switch to manual mode.
path = ROOT / "Mira/App/MiraStore+Planning.swift"
text = path.read_text(encoding="utf-8")
old = '''            if let entity = try context.fetch(descriptor).first {
                entity.targetCount = max(0, target)
                entity.isEnabled = target > 0
                try context.save()
'''
new = '''            if let entity = try context.fetch(descriptor).first {
                entity.targetCount = max(0, target)
                entity.isEnabled = target > 0
                automaticMarginTargetsEnabled = false
                settingsEntity?.automaticMarginTargetsEnabled = false
                settingsEntity?.updatedAt = .now
                try context.save()
'''
if old in text:
    text = text.replace(old, new, 1)
path.write_text(text, encoding="utf-8")

print("Automatic/manual margin planning mode persisted.")
