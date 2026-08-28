#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write(path: str, content: str) -> None:
    (ROOT / path).write_text(content, encoding="utf-8")


def replace_once(path: str, old: str, new: str) -> None:
    text = read(path)
    if new in text:
        return
    if old not in text:
        raise RuntimeError(f"Expected block not found in {path}: {old[:100]!r}")
    write(path, text.replace(old, new, 1))


def replace_all(path: str, old: str, new: str) -> None:
    text = read(path)
    if old not in text:
        return
    write(path, text.replace(old, new))


# Layout proposal initializer is explicit for Xcode/Swift compatibility.
replace_all(
    "Mira/DesignSystem/FlowLayout.swift",
    "proposal: ProposedViewSize(size)",
    "proposal: ProposedViewSize(width: size.width, height: size.height)",
)

# Rule-based interpretation recognizes pasted invitation wording.
replace_once(
    "Mira/Services/ConversationAssistantService.swift",
    '''        if text.contains("行けそう") || text.contains("いけそう") || text.contains("行ける") || text.contains("空いてる") {
            return .checkInvitation
        }
''',
    '''        if text.contains("行けそう") || text.contains("いけそう") || text.contains("行ける") || text.contains("空いてる") ||
            text.contains("誘われ") || text.contains("どっち") || text.contains("飲まん") || text.contains("どう？") || text.contains("どうかな") {
            return .checkInvitation
        }
''',
)

# Keep unrelated new requests from being attached to the last active case, while
# preserving short natural follow-ups such as 「夜はなし」「じゃあ土曜」.
replace_once(
    "Mira/App/MiraStore+Conversation.swift",
    '''        let activeContext = contextResult(forCaseID: activeConversationCaseID)
        let effectivePinned = pinnedContext ?? activeContext
''',
    '''        let activeContext = shouldContinueActiveCase(with: text)
            ? contextResult(forCaseID: activeConversationCaseID)
            : nil
        let effectivePinned = pinnedContext ?? activeContext
''',
)

# Detailed time becomes real exact-time candidate data at commit time.
replace_once(
    "Mira/App/MiraStore+Conversation.swift",
    '''        let candidates = selected.map(\\.candidateSnapshot)
''',
    '''        let candidates = selected.map { recommendation -> CandidateSlotSnapshot in
            var candidate = recommendation.candidateSnapshot
            if draft.detailedTimeEnabled,
               let hour = draft.detailedStartHour,
               let minute = draft.detailedStartMinute {
                let start = recommendation.day.setting(hour: hour, minute: minute)
                candidate.startDate = start
                candidate.endDate = start.addingTimeInterval(
                    TimeInterval(draft.durationBucket.representativeMinutes * 60)
                )
                candidate.exactTimeKnown = true
            }
            return candidate
        }
''',
)

# A time-only update (「19時からになった」) must retain the existing event date.
replace_once(
    "Mira/App/MiraStore+Conversation.swift",
    '''        if let exactStart = interpretation.exactStartDate {
            let oldDuration = max(30 * 60, before.endDate.timeIntervalSince(before.startDate))
            after.startDate = exactStart
            after.endDate = interpretation.exactEndDate ?? exactStart.addingTimeInterval(oldDuration)
            after.exactTimeKnown = true
            after.schedulingTimeBand = schedulingBand(for: exactStart)
''',
    '''        if let parsedExactStart = interpretation.exactStartDate {
            let components = Calendar.mira.dateComponents([.hour, .minute], from: parsedExactStart)
            let targetDay = interpretation.candidateDates.first ?? before.startDate
            let exactStart = targetDay.setting(
                hour: components.hour ?? 19,
                minute: components.minute ?? 0
            )
            let oldDuration = max(30 * 60, before.endDate.timeIntervalSince(before.startDate))
            after.startDate = exactStart
            after.endDate = exactStart.addingTimeInterval(oldDuration)
            after.exactTimeKnown = true
            after.schedulingTimeBand = schedulingBand(for: exactStart)
''',
)

# Exclude the edited event itself from conflict detection.
replace_once(
    "Mira/App/MiraStore+Conversation.swift",
    '''        let conflicts = eventEntryConflicts(for: after).filter { message in
            if message.contains(before.title) { return false }
            return true
        }
''',
    '''        let conflicts = conversationConflicts(for: after, excludingItemID: before.id)
''',
)

marker = '''    private func summaryReply(
'''
insert = '''    private func shouldContinueActiveCase(with text: String) -> Bool {
        guard let active = conversationCase(id: activeConversationCaseID) else { return false }
        let elapsed = now.timeIntervalSince(active.lastActivityAt)
        guard elapsed < 30 * 60 else { return false }
        if text.count <= 24 { return true }
        let followUpWords = ["やっぱ", "じゃあ", "それ", "その件", "夜は", "昼は", "朝は", "土曜", "日曜", "来週なら", "断る文", "送る文"]
        return followUpWords.contains(where: text.contains)
    }

    private func conversationConflicts(
        for event: CalendarItemSnapshot,
        excludingItemID: UUID
    ) -> [String] {
        let band = event.schedulingTimeBand?.legacyTimeOfDay ?? {
            if event.isAllDay { return TimeOfDayKind.allDay }
            let hour = Calendar.mira.component(.hour, from: event.startDate)
            if hour < 12 { return .morning }
            if hour < 17 { return .afternoon }
            return .evening
        }()
        let candidate = CandidateSlotSnapshot(
            startDate: event.occupiedInterval.start,
            endDate: event.occupiedInterval.end,
            timeOfDay: band,
            schedulingTimeBand: event.schedulingTimeBand,
            durationBucket: event.durationBucket,
            exactTimeKnown: event.exactTimeKnown
        )
        return ConflictEngine().conflicts(
            candidate: candidate,
            events: items.filter { $0.id != excludingItemID },
            otherCandidates: heldCandidates(),
            baseRules: fetchBaseRules()
        )
    }

'''
text = read("Mira/App/MiraStore+Conversation.swift")
if "private func shouldContinueActiveCase" not in text:
    if marker not in text:
        raise RuntimeError("Insertion marker missing in MiraStore+Conversation.swift")
    text = text.replace(marker, insert + marker, 1)
    write("Mira/App/MiraStore+Conversation.swift", text)

# Fast Japanese search strips common conversational wrappers before token ranking.
replace_once(
    "Mira/Services/CaseSearchEngine.swift",
    '''    private func normalize(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .widthInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ja_JP"))
            .replacingOccurrences(of: "　", with: " ")
            .replacingOccurrences(of: "[^\\p{L}\\p{N}]", with: " ", options: .regularExpression)
            .split(whereSeparator: \\.isWhitespace)
            .joined(separator: " ")
            .lowercased()
    }
''',
    '''    private func normalize(_ text: String) -> String {
        var value = text
            .folding(options: [.caseInsensitive, .widthInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ja_JP"))
            .replacingOccurrences(of: "　", with: " ")
            .lowercased()
        for wrapper in ["の件", "のやつ", "について", "ってさ", "って", "さー", "さあ"] {
            value = value.replacingOccurrences(of: wrapper, with: " ")
        }
        return value
            .replacingOccurrences(of: "[^\\p{L}\\p{N}]", with: " ", options: .regularExpression)
            .split(whereSeparator: \\.isWhitespace)
            .joined(separator: " ")
    }
''',
)

# Tuple key paths are not reliable in SwiftUI ForEach; render dictionary rows by enum keys.
result_path = "Mira/Features/Conversation/ConversationResultSheets.swift"
text = read(result_path)
text = text.replace(
    '''            ForEach(sortedDeficits, id: \\.0) { kind, deficit in
                Text("・\\(kind.title)があと\\(deficit)枠必要")
''',
    '''            ForEach(sortedDeficitKinds) { kind in
                Text("・\\(kind.title)があと\\(preview.impact.projectedGoalDeficits[kind, default: 0])枠必要")
''',
)
text = text.replace(
    '''    private var sortedDeficits: [(MarginKind, Int)] {
        preview.impact.projectedGoalDeficits.sorted { $0.key.defaultPriority > $1.key.defaultPriority }
    }
''',
    '''    private var sortedDeficitKinds: [MarginKind] {
        preview.impact.projectedGoalDeficits.keys.sorted { $0.defaultPriority > $1.defaultPriority }
    }
''',
)
text = text.replace(
    '''                            ForEach(sortedDeficits, id: \\.0) { kind, deficit in
                                HStack {
                                    Image(systemName: kind.symbolName)
                                        .foregroundStyle(palette.warning)
                                    Text("\\(kind.title)があと\\(deficit)枠不足")
''',
    '''                            ForEach(sortedDeficitKinds) { kind in
                                HStack {
                                    Image(systemName: kind.symbolName)
                                        .foregroundStyle(palette.warning)
                                    Text("\\(kind.title)があと\\(preview.impact.projectedGoalDeficits[kind, default: 0])枠不足")
''',
)
text = text.replace(
    '''    private var sortedDeficits: [(MarginKind, Int)] {
        preview.impact.projectedGoalDeficits.sorted { $0.key.defaultPriority > $1.key.defaultPriority }
    }
''',
    '''    private var sortedDeficitKinds: [MarginKind] {
        preview.impact.projectedGoalDeficits.keys.sorted { $0.defaultPriority > $1.defaultPriority }
    }
''',
    1,
)
text = re.sub(
    r'''ForEach\(recommendation\.targets\.sorted\(by: \{ \$0\.key\.defaultPriority > \$1\.key\.defaultPriority \}\), id: \\.key\) \{ kind, count in''',
    '''ForEach(recommendedKinds) { kind in''',
    text,
)
text = text.replace('''                                    Text("\\(count)回")''', '''                                    Text("\\(recommendation.targets[kind, default: 0])回")''')
if "private var recommendedKinds" not in text:
    marker = '''    private var previewRecommendation: MarginRecommendation? {
'''
    addition = '''    private var recommendedKinds: [MarginKind] {
        guard let recommendation = previewRecommendation else { return [] }
        return recommendation.targets.keys.sorted { $0.defaultPriority > $1.defaultPriority }
    }

'''
    text = text.replace(marker, addition + marker, 1)
write(result_path, text)

# Recalculate recommended margin amount and rebalance proposal after all relevant writes.
replace_once(
    "Mira/App/MiraStore+EventEntry.swift",
    '''            try context.save()
            try refresh()
            toast = resolution == .exception && !impact.overlappingMargins.isEmpty
''',
    '''            try context.save()
            try refresh()
            updateMarginRecommendation(for: event.startDate)
            recalculateBalance(for: event.startDate)
            toast = resolution == .exception && !impact.overlappingMargins.isEmpty
''',
)

planning = "Mira/App/MiraStore+Planning.swift"
text = read(planning)
text = text.replace(
    '''            try context.save()
            try refresh()
            toast = "予定を追加したにゃ"
''',
    '''            try context.save()
            try refresh()
            updateMarginRecommendation(for: event.startDate)
            recalculateBalance(for: event.startDate)
            toast = "予定を追加したにゃ"
''',
    1,
)
text = text.replace(
    '''            try context.save()
            try refresh()
            toast = "移動したにゃ"
''',
    '''            try context.save()
            try refresh()
            updateMarginRecommendation(for: newStart)
            recalculateBalance(for: newStart)
            toast = "移動したにゃ"
''',
    1,
)
text = text.replace(
    '''                context.delete(entity)
                try context.save()
                try refresh()
''',
    '''                let affectedDate = entity.startDate
                context.delete(entity)
                try context.save()
                try refresh()
                updateMarginRecommendation(for: affectedDate)
                recalculateBalance(for: affectedDate)
''',
    1,
)
write(planning, text)

# Stable state hash and unambiguous delete closures.
replace_all(
    "Mira/App/MiraStore+Recommendations.swift",
    "existing.forEach(context.delete)",
    "existing.forEach { context.delete($0) }",
)
replace_once(
    "Mira/Domain/MarginRecommendationEngine.swift",
    '''        return String((itemPart + "#" + goalPart).hashValue)
''',
    '''        let source = itemPart + "#" + goalPart
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in source.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
''',
)

# Coarse candidate labels should remain coarse in existing adjustment screens.
models = "Mira/Domain/DomainModels.swift"
text = read(models)
if "var displayDescription: String" not in text:
    marker = '''    var displayDuration: DurationBucket {
        durationBucket ?? (timeOfDay == .allDay ? .fullDay : .short)
    }
'''
    addition = marker + '''

    var displayDescription: String {
        if exactTimeKnown == false {
            return "\\(displayTimeBand.title)・時間未定・\\(displayDuration.title)"
        }
        if timeOfDay == .allDay { return "終日" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "H:mm"
        return "\\(formatter.string(from: startDate))–\\(formatter.string(from: endDate))"
    }
'''
    if marker not in text:
        raise RuntimeError("Candidate display marker missing")
    text = text.replace(marker, addition, 1)
    write(models, text)

# Add generated-skin roadmap to README if a docs section exists; otherwise append.
readme_path = ROOT / "README.md"
if readme_path.exists():
    readme = readme_path.read_text(encoding="utf-8")
    link = "- [生成画像スキン制作ロードマップ](docs/roadmap-generated-skins.md)"
    if link not in readme:
        readme += "\n\n## 後続デザイン制作\n\n" + link + "\n"
        readme_path.write_text(readme, encoding="utf-8")

print("Grill-Me finalization patches applied.")
