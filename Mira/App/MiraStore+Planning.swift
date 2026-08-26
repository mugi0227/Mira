import Foundation
import SwiftData

@MainActor
extension MiraStore {
    func finishOnboarding(targets: [MarginKind: Int]) {
        do {
            onboardingCompleted = true
            settingsEntity?.onboardingCompleted = true
            settingsEntity?.updatedAt = .now

            for offset in 0...2 {
                let month = selectedMonth.addingMonths(offset)
                try DemoSeeder.seedDefaultGoals(in: context, month: month, targets: targets, calendar: .mira)
            }
            try context.save()
            try refresh()
            autoPlaceMargins(for: selectedMonth)
        } catch {
            toast = "初期設定を保存できませんでした"
        }
    }

    func ensurePlan(for month: Date, provisional: Bool = true) {
        let key = MonthKey(date: month)
        guard !goals.contains(where: { $0.year == key.year && $0.month == key.month }) else { return }
        do {
            let previous = month.addingMonths(-1)
            let previousKey = MonthKey(date: previous)
            let previousGoals = goals.filter { $0.year == previousKey.year && $0.month == previousKey.month }
            let targets = Dictionary(uniqueKeysWithValues: previousGoals.map { ($0.kind, $0.targetCount) })
            try DemoSeeder.seedDefaultGoals(in: context, month: month, targets: targets, calendar: .mira)
            try refresh()
            if provisional {
                toast = "前の月と同じ余白を、いったん置いておいたにゃ"
            }
        } catch {
            toast = "未来月の設定を作れませんでした"
        }
    }

    func autoPlaceMargins(for month: Date) {
        ensurePlan(for: month, provisional: false)
        let key = MonthKey(date: month)
        let monthGoals = goals.filter { $0.year == key.year && $0.month == key.month }
        let monthItems = items.filter { key.interval.contains($0.startDate) }
        let existingMargins = monthItems.filter { $0.kind == .margin }
        let events = monthItems.filter { $0.kind != .margin }
        let baseRules = fetchBaseRules()
        let proposal = scheduler.propose(
            month: month,
            goals: monthGoals,
            events: events,
            existingMargins: existingMargins,
            baseRules: baseRules
        )
        do {
            proposal.slots.forEach { context.insert(CalendarItemEntity(snapshot: $0)) }
            try context.save()
            try refresh()
            toast = proposal.unmetGoals.isEmpty
                ? "余白をいい感じに置いたにゃ"
                : "置けなかった余白もあるので、あとで見直してにゃ"
        } catch {
            toast = "余白を配置できませんでした"
        }
    }

    func prepareEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        isImportant: Bool
    ) async -> CalendarItemSnapshot {
        let semantic = await classifier.classify(
            title: title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay
        )
        let evaluation = loadEngine.evaluate(
            title: title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            semantic: semantic,
            explicitRules: fetchLoadRules()
        )
        return CalendarItemSnapshot(
            id: UUID(),
            title: title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            kind: .confirmed,
            marginKind: nil,
            loadClass: evaluation.loadClass,
            loadReason: evaluation.reason,
            bufferBeforeMinutes: evaluation.bufferBeforeMinutes,
            bufferAfterMinutes: evaluation.bufferAfterMinutes,
            isImportantTime: isImportant,
            sourceID: nil
        )
    }

    func previewImpact(for event: CalendarItemSnapshot) -> ScheduleImpact {
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

    func commitEvent(
        _ event: CalendarItemSnapshot,
        impact: ScheduleImpact = .none,
        resolution: ImpactResolution = .exception,
        chosenRelocationDate: Date? = nil
    ) {
        do {
            if resolution == .relocate, let date = chosenRelocationDate ?? impact.relocationCandidates.first {
                for margin in impact.overlappingMargins {
                    try moveMargin(margin, to: date)
                }
            }
            context.insert(CalendarItemEntity(snapshot: event))
            try context.save()
            try refresh()
            toast = "予定を追加したにゃ"
        } catch {
            toast = "予定を保存できませんでした"
        }
    }

    func addMargin(kind: MarginKind, on date: Date) {
        let duration = kind.defaultDurationHours
        let startHour = kind == .rest ? 9 : (kind == .freeEvening || kind == .solo ? 18 : 13)
        let start = date.setting(hour: startHour)
        let end = Calendar.mira.date(byAdding: .hour, value: duration, to: start) ?? start
        let snapshot = CalendarItemSnapshot(
            id: UUID(),
            title: kind.title,
            startDate: start,
            endDate: end,
            isAllDay: kind == .rest,
            kind: .margin,
            marginKind: kind,
            loadClass: .light,
            loadReason: "自分のために確保した余白",
            bufferBeforeMinutes: 0,
            bufferAfterMinutes: 0,
            isImportantTime: false,
            sourceID: nil
        )
        context.insert(CalendarItemEntity(snapshot: snapshot))
        try? context.save()
        try? refresh()
    }

    func moveItem(id: UUID, to date: Date) {
        do {
            guard let entity = try entity(id: id) else { return }
            let duration = entity.endDate.timeIntervalSince(entity.startDate)
            let oldComponents = Calendar.mira.dateComponents([.hour, .minute], from: entity.startDate)
            let newStart = date.setting(hour: oldComponents.hour ?? 9, minute: oldComponents.minute ?? 0)
            entity.startDate = newStart
            entity.endDate = newStart.addingTimeInterval(duration)
            entity.updatedAt = .now
            try context.save()
            try refresh()
            toast = "移動したにゃ"
        } catch {
            toast = "移動できませんでした"
        }
    }

    func deleteItem(id: UUID) {
        do {
            if let entity = try entity(id: id) {
                context.delete(entity)
                try context.save()
                try refresh()
            }
        } catch {
            toast = "削除できませんでした"
        }
    }

    func correctLoad(itemID: UUID, to load: LoadClass, rememberKeyword: Bool) {
        do {
            guard let entity = try entity(id: itemID) else { return }
            entity.loadRaw = load.rawValue
            entity.loadReason = "あなたが明示的に変更した負荷"
            if rememberKeyword {
                context.insert(LoadRuleEntity(keyword: entity.title, loadClass: load))
            }
            try context.save()
            try refresh()
            toast = rememberKeyword ? "似た予定にも覚えておくにゃ" : "この予定だけ直したにゃ"
        } catch {
            toast = "負荷を変更できませんでした"
        }
    }

    func progress(for goal: MarginGoalSnapshot) -> (current: Int, target: Int) {
        let key = MonthKey(year: goal.year, month: goal.month)
        let current: Int
        if goal.kind == .importantPeople {
            current = items.filter { $0.isImportantTime && key.interval.contains($0.startDate) }.count
        } else if goal.kind == .freeEvening {
            let engine = FreeEveningEngine()
            let days = daysInMonth(key.firstDay)
            current = Int(days.reduce(0.0) { total, date in
                total + engine.value(for: date, items: items.filter { Calendar.mira.isDate($0.startDate, inSameDayAs: date) })
            }.rounded(.down))
        } else {
            current = items.filter {
                $0.kind == .margin && $0.marginKind == goal.kind && key.interval.contains($0.startDate)
            }.count
        }
        return (current, goal.targetCount)
    }

    func updateGoal(_ goal: MarginGoalSnapshot, target: Int) {
        do {
            let goalID = goal.id
            var descriptor = FetchDescriptor<MarginGoalEntity>(predicate: #Predicate { $0.id == goalID })
            descriptor.fetchLimit = 1
            if let entity = try context.fetch(descriptor).first {
                entity.targetCount = max(0, target)
                entity.isEnabled = target > 0
                try context.save()
                try refresh()
            }
        } catch {
            toast = "目標を変更できませんでした"
        }
    }
}
