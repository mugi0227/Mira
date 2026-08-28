#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def load(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def save(path: str, text: str) -> None:
    (ROOT / path).write_text(text, encoding="utf-8")


def sub(path: str, pattern: str, replacement: str, *, flags: int = 0) -> None:
    text = load(path)
    updated, count = re.subn(pattern, replacement, text, count=1, flags=flags)
    if count:
        save(path, updated)


# Cross-file setter access.
sub(
    "Mira/App/MiraStore.swift",
    r"private\(set\) var isInterpretingConversation = false",
    "var isInterpretingConversation = false",
)

# Deterministic UI-test reset.
store_path = "Mira/App/MiraStore.swift"
store = load(store_path)
if 'ProcessInfo.processInfo.arguments.contains("-reset-demo")' not in store:
    needle = "            try DemoSeeder.seedBaseline(in: context, clock: clock)\n            try refresh()\n"
    replacement = '''            if ProcessInfo.processInfo.arguments.contains("-reset-demo") {
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
'''
    if needle in store:
        save(store_path, store.replace(needle, replacement, 1))

conversation_path = "Mira/App/MiraStore+Conversation.swift"
conversation = load(conversation_path)

if "shouldContinueActiveCase(with: text)" not in conversation:
    conversation = conversation.replace(
        "        let activeContext = contextResult(forCaseID: activeConversationCaseID)\n        let effectivePinned = pinnedContext ?? activeContext\n",
        "        let activeContext = shouldContinueActiveCase(with: text)\n            ? contextResult(forCaseID: activeConversationCaseID)\n            : nil\n        let effectivePinned = pinnedContext ?? activeContext\n",
        1,
    )

if "draft.detailedTimeEnabled" not in conversation.split("func commitSchedulingDraft", 1)[-1].split("func applyChangePreview", 1)[0]:
    conversation = conversation.replace(
        r"        let candidates = selected.map(\.candidateSnapshot)".replace("\\\\", "\\"),
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
        }''',
        1,
    )

if "let parsedExactStart = interpretation.exactStartDate" not in conversation:
    conversation = conversation.replace(
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
        1,
    )

conversation = conversation.replace(
    '''        let conflicts = eventEntryConflicts(for: after).filter { message in
            if message.contains(before.title) { return false }
            return true
        }
''',
    '''        let conflicts = conversationConflicts(for: after, excludingItemID: before.id)
''',
    1,
)

if "private func shouldContinueActiveCase" not in conversation:
    marker = "    private func summaryReply(\n"
    helpers = '''    private func shouldContinueActiveCase(with text: String) -> Bool {
        guard let active = conversationCase(id: activeConversationCaseID) else { return false }
        guard now.timeIntervalSince(active.lastActivityAt) < 30 * 60 else { return false }
        if text.count <= 24 { return true }
        let words = ["やっぱ", "じゃあ", "それ", "その件", "夜は", "昼は", "朝は", "土曜", "日曜", "来週なら", "断る文", "送る文"]
        return words.contains(where: text.contains)
    }

    private func conversationConflicts(
        for event: CalendarItemSnapshot,
        excludingItemID: UUID
    ) -> [String] {
        let timeOfDay: TimeOfDayKind
        if let band = event.schedulingTimeBand {
            timeOfDay = band.legacyTimeOfDay
        } else if event.isAllDay {
            timeOfDay = .allDay
        } else {
            let hour = Calendar.mira.component(.hour, from: event.startDate)
            timeOfDay = hour < 12 ? .morning : hour < 17 ? .afternoon : .evening
        }
        let candidate = CandidateSlotSnapshot(
            startDate: event.occupiedInterval.start,
            endDate: event.occupiedInterval.end,
            timeOfDay: timeOfDay,
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
    if marker in conversation:
        conversation = conversation.replace(marker, helpers + marker, 1)

old_month = '''        if let month {
            draft.month = month
            let key = MonthKey(date: month)
            draft.dateRangeStart = max(draft.dateRangeStart, key.firstDay)
            draft.dateRangeEnd = min(draft.dateRangeEnd, key.interval.end.addingTimeInterval(-1))
        }
'''
new_month = '''        if let month {
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
'''
conversation = conversation.replace(old_month, new_month, 1)
save(conversation_path, conversation)

# Invitation language recognition.
service_path = "Mira/Services/ConversationAssistantService.swift"
service = load(service_path)
old = '''        if text.contains("行けそう") || text.contains("いけそう") || text.contains("行ける") || text.contains("空いてる") {
            return .checkInvitation
        }
'''
new = '''        if text.contains("行けそう") || text.contains("いけそう") || text.contains("行ける") || text.contains("空いてる") ||
            text.contains("誘われ") || text.contains("どっち") || text.contains("飲まん") || text.contains("どう？") || text.contains("どうかな") {
            return .checkInvitation
        }
'''
service = service.replace(old, new, 1)
save(service_path, service)

# Faster Japanese term normalization.
search_path = "Mira/Services/CaseSearchEngine.swift"
search = load(search_path)
if 'for wrapper in ["の件"' not in search:
    start = search.find("    private func normalize(_ text: String) -> String {")
    end = search.find("\n    private func searchTokens", start)
    if start >= 0 and end > start:
        replacement = '''    private func normalize(_ text: String) -> String {
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
'''
        search = search[:start] + replacement + search[end:]
save(search_path, search)

# SwiftUI dictionary rows without tuple key paths.
result_path = "Mira/Features/Conversation/ConversationResultSheets.swift"
result = load(result_path)
result = result.replace(
    r"ForEach(sortedDeficits, id: \.0) { kind, deficit in".replace("\\\\", "\\"),
    "ForEach(sortedDeficitKinds) { kind in",
)
result = result.replace("\\(deficit)枠必要", "\\(preview.impact.projectedGoalDeficits[kind, default: 0])枠必要")
result = result.replace("\\(deficit)枠不足", "\\(preview.impact.projectedGoalDeficits[kind, default: 0])枠不足")
result = result.replace(
    '''    private var sortedDeficits: [(MarginKind, Int)] {
        preview.impact.projectedGoalDeficits.sorted { $0.key.defaultPriority > $1.key.defaultPriority }
    }
''',
    '''    private var sortedDeficitKinds: [MarginKind] {
        preview.impact.projectedGoalDeficits.keys.sorted { $0.defaultPriority > $1.defaultPriority }
    }
''',
)
result = result.replace(
    r"ForEach(recommendation.targets.sorted(by: { $0.key.defaultPriority > $1.key.defaultPriority }), id: \.key) { kind, count in".replace("\\\\", "\\"),
    "ForEach(recommendedKinds) { kind in",
)
result = result.replace('Text("\\(count)回")', 'Text("\\(recommendation.targets[kind, default: 0])回")')
if "private var recommendedKinds" not in result:
    marker = "    private var previewRecommendation: MarginRecommendation? {\n"
    addition = '''    private var recommendedKinds: [MarginKind] {
        guard let recommendation = previewRecommendation else { return [] }
        return recommendation.targets.keys.sorted { $0.defaultPriority > $1.defaultPriority }
    }

'''
    result = result.replace(marker, addition + marker, 1)
save(result_path, result)

# Build-safe layout proposal.
flow_path = "Mira/DesignSystem/FlowLayout.swift"
flow = load(flow_path).replace("proposal.width ?? .infinity", "proposal.width ?? 10_000")
flow = flow.replace("proposal: ProposedViewSize(size)", "proposal: ProposedViewSize(width: size.width, height: size.height)")
save(flow_path, flow)

# Recalculate balance after all direct calendar writes.
event_path = "Mira/App/MiraStore+EventEntry.swift"
event = load(event_path)
needle = '''            try context.save()
            try refresh()
            toast = resolution == .exception && !impact.overlappingMargins.isEmpty
'''
if "updateMarginRecommendation(for: event.startDate)" not in event:
    event = event.replace(
        needle,
        '''            try context.save()
            try refresh()
            updateMarginRecommendation(for: event.startDate)
            recalculateBalance(for: event.startDate)
            toast = resolution == .exception && !impact.overlappingMargins.isEmpty
''',
        1,
    )
save(event_path, event)

planning_path = "Mira/App/MiraStore+Planning.swift"
planning = load(planning_path)
if "updateMarginRecommendation(for: event.startDate)" not in planning:
    planning = planning.replace(
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
if "updateMarginRecommendation(for: newStart)" not in planning:
    planning = planning.replace(
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
if "let affectedDate = entity.startDate" not in planning:
    planning = planning.replace(
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
save(planning_path, planning)

recommendations_path = "Mira/App/MiraStore+Recommendations.swift"
recommendations = load(recommendations_path).replace("existing.forEach(context.delete)", "existing.forEach { context.delete($0) }")
save(recommendations_path, recommendations)

# Candidate label helper.
models_path = "Mira/Domain/DomainModels.swift"
models = load(models_path)
if "var displayDescription: String" not in models:
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
    models = models.replace(marker, addition, 1)
save(models_path, models)

# Stable FNV-1a proposal hash.
margin_path = "Mira/Domain/MarginRecommendationEngine.swift"
margin = load(margin_path)
margin = margin.replace(
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
    1,
)
save(margin_path, margin)

# README roadmap link.
readme_path = ROOT / "README.md"
if readme_path.exists():
    readme = readme_path.read_text(encoding="utf-8")
    link = "- [生成画像スキン制作ロードマップ](docs/roadmap-generated-skins.md)"
    if link not in readme:
        readme += "\n\n## 後続デザイン制作\n\n" + link + "\n"
        readme_path.write_text(readme, encoding="utf-8")

print("Grill-Me hardening applied.")
