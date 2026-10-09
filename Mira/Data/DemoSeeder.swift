import Foundation
import SwiftData

@MainActor
enum DemoSeeder {
    static func seedBaseline(in context: ModelContext, clock: MiraClock) throws {
        let existingEvents = try context.fetch(FetchDescriptor<CalendarItemEntity>())
        guard existingEvents.isEmpty else { return }

        let engine = LoadEngine(calendar: clock.calendar)
        let base = clock.now.startOfDay(calendar: clock.calendar)

        let specifications: [(String, Int, Int, Int, Bool, Bool, CalendarItemKind)] = [
            ("仕事", 1, 9, 9, false, false, .confirmed),
            ("みんなでご飯", 4, 18, 4, false, true, .confirmed),
            ("美容院", 6, 11, 2, true, false, .confirmed),
            ("映画とカフェ", 8, 13, 6, false, false, .confirmed),
            ("会社の飲み会", 10, 19, 4, false, false, .confirmed),
            ("友達と一日おでかけ", 12, 10, 10, true, false, .confirmed),
            ("読書会", 15, 18, 3, false, false, .confirmed),
            ("ライブ", 18, 15, 8, false, false, .confirmed),
            ("恋人とデート", 20, 11, 9, false, true, .confirmed),
            ("友達の誕生日", 22, 9, 1, true, false, .birthday),
            ("週末旅行", 25, 8, 14, true, false, .confirmed),
            ("歯医者", 29, 18, 1, false, false, .confirmed),

            ("親友とランチ", 35, 12, 4, false, true, .confirmed),
            ("映画", 39, 18, 4, false, false, .confirmed),
            ("会社の歓迎会", 43, 19, 4, false, false, .confirmed),
            ("家族と外食", 50, 18, 4, false, true, .confirmed),

            ("秋の旅行", 66, 8, 14, true, false, .confirmed),
            ("ライブ", 73, 16, 7, false, false, .confirmed),
            ("友達と遊ぶ", 80, 11, 9, true, false, .confirmed)
        ]

        let demoColors: [String: EventColorTag] = [
            "仕事": .redLight, "会社の飲み会": .redLight, "会社の歓迎会": .redLight,
            "みんなでご飯": .sky, "友達と一日おでかけ": .sky, "親友とランチ": .sky, "友達と遊ぶ": .sky,
            "恋人とデート": .pink, "家族と外食": .orangeLight,
            "映画とカフェ": .sky, "映画": .sky, "ライブ": .skyLight,
            "週末旅行": .skyDeep, "秋の旅行": .skyDeep,
            "美容院": .greenLight, "歯医者": .greenLight, "読書会": .yellowLight
        ]

        for spec in specifications {
            let day = base.addingDays(spec.1, calendar: clock.calendar)
            let start = day.setting(hour: spec.2, calendar: clock.calendar)
            let end = clock.calendar.date(byAdding: .hour, value: spec.3, to: start) ?? start
            let evaluation = engine.evaluate(
                title: spec.0,
                startDate: start,
                endDate: end,
                isAllDay: spec.4
            )
            var snapshot = CalendarItemSnapshot(
                id: UUID(),
                title: spec.0,
                startDate: start,
                endDate: end,
                isAllDay: spec.4,
                kind: spec.6,
                marginKind: nil,
                loadClass: evaluation.loadClass,
                loadReason: evaluation.reason,
                bufferBeforeMinutes: evaluation.bufferBeforeMinutes,
                bufferAfterMinutes: evaluation.bufferAfterMinutes,
                isImportantTime: spec.5,
                sourceID: nil
            )
            snapshot.colorTag = demoColors[spec.0]
            context.insert(CalendarItemEntity(snapshot: snapshot))
        }

        let baseRules = try context.fetch(FetchDescriptor<BaseRuleEntity>())
        if baseRules.isEmpty {
            for weekday in 2...6 {
                context.insert(BaseRuleEntity(weekday: weekday, startMinute: 9 * 60, endMinute: 18 * 60))
            }
        }

        try seedAdjustments(in: context, base: base, calendar: clock.calendar)
        try context.save()
    }

    static func seedDefaultGoals(
        in context: ModelContext,
        month: Date,
        targets: [MarginKind: Int],
        calendar: Calendar
    ) throws {
        let key = MonthKey(date: month, calendar: calendar)
        let allGoals = try context.fetch(FetchDescriptor<MarginGoalEntity>())
        let existingKinds = Set(allGoals.filter { $0.year == key.year && $0.month == key.month }.map(\.kindRaw))

        let defaults = targets.isEmpty ? [
            MarginKind.rest: 4,
            .reading: 2,
            .personalProject: 2,
            .importantPeople: 2
        ] : targets

        for (kind, count) in defaults where !existingKinds.contains(kind.rawValue) {
            let goal = MarginGoalSnapshot(
                id: UUID(),
                year: key.year,
                month: key.month,
                kind: kind,
                targetCount: count,
                durationHours: kind.defaultDurationHours,
                priority: kind.defaultPriority,
                isEnabled: count > 0
            )
            context.insert(MarginGoalEntity(snapshot: goal))
        }
        try context.save()
    }

    private static func seedAdjustments(in context: ModelContext, base: Date, calendar: Calendar) throws {
        let sessions = try context.fetch(FetchDescriptor<AdjustmentEntity>())
        guard sessions.isEmpty else { return }

        let firstCandidates = [
            candidate(on: base.addingDays(37, calendar: calendar), time: .afternoon, calendar: calendar),
            candidate(on: base.addingDays(44, calendar: calendar), time: .afternoon, calendar: calendar),
            candidate(on: base.addingDays(45, calendar: calendar), time: .evening, calendar: calendar)
        ]
        context.insert(AdjustmentEntity(
            title: "カフェに行く",
            contactName: "友達",
            responseDeadline: base.addingDays(31, calendar: calendar),
            candidates: firstCandidates,
            generatedMessage: Self.message(title: "カフェ", candidates: firstCandidates)
        ))

        let secondCandidates = [
            candidate(on: base.addingDays(44, calendar: calendar), time: .afternoon, calendar: calendar),
            candidate(on: base.addingDays(51, calendar: calendar), time: .evening, calendar: calendar)
        ]
        context.insert(AdjustmentEntity(
            title: "美術館",
            contactName: "別の友達",
            responseDeadline: base.addingDays(33, calendar: calendar),
            candidates: secondCandidates,
            generatedMessage: Self.message(title: "美術館", candidates: secondCandidates)
        ))

        let pendingCandidates = [
            candidate(on: base.addingDays(14, calendar: calendar), time: .evening, calendar: calendar)
        ]
        context.insert(PendingInvitationEntity(
            title: "平日の夜にご飯",
            contactName: "友達",
            memo: "まだ返事していない",
            replyDeadline: base.addingDays(4, calendar: calendar),
            candidates: pendingCandidates
        ))
    }

    private static func candidate(on day: Date, time: TimeOfDayKind, calendar: Calendar) -> CandidateSlotSnapshot {
        let hours: (Int, Int)
        switch time {
        case .allDay: hours = (9, 21)
        case .morning: hours = (9, 12)
        case .afternoon: hours = (13, 17)
        case .evening: hours = (18, 22)
        }
        let start = day.setting(hour: hours.0, calendar: calendar)
        let end = day.setting(hour: hours.1, calendar: calendar)
        return CandidateSlotSnapshot(startDate: start, endDate: end, timeOfDay: time)
    }

    static func message(title: String, candidates: [CandidateSlotSnapshot]) -> String {
        let dayFormatter = DateFormatter.mira("M/d（E）")

        let timeFormatter = DateFormatter.mira("H:mm")

        let lines = candidates
            .filter { $0.status != .released }
            .sorted { $0.startDate < $1.startDate }
            .map { candidate -> String in
                let day = dayFormatter.string(from: candidate.startDate)
                if candidate.exactTimeKnown == false {
                    return "・\(day) \(candidate.displayTimeBand.title)あたり"
                }
                if candidate.timeOfDay == .allDay {
                    return "・\(day) 終日"
                }
                return "・\(day) \(timeFormatter.string(from: candidate.startDate))〜"
            }

        return "候補日です！\n\(lines.joined(separator: "\n"))\n\(title)に都合よさそうな日を教えてください。"
    }
}
