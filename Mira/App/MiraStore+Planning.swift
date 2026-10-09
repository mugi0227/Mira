import Foundation
import SwiftData

@MainActor
extension MiraStore {
    func finishOnboarding(targets: [MarginKind: Int]) {
        do {
            onboardingCompleted = true
            settingsEntity?.onboardingCompleted = true
            settingsEntity?.updatedAt = .now

            let canonicalTargets = Dictionary(
                targets.map { ($0.key.canonicalKind, $0.value) },
                uniquingKeysWith: { current, _ in current }
            )

            for offset in 0...2 {
                let month = selectedMonth.addingMonths(offset)
                try DemoSeeder.seedDefaultGoals(in: context, month: month, targets: canonicalTargets, calendar: .mira)
            }
            try context.save()
            try refresh()
            autoPlaceMargins(for: selectedMonth)
        } catch {
            context.rollback()
            onboardingCompleted = false
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
            context.rollback()
            toast = "未来月の設定を作れませんでした"
        }
    }

    func autoPlaceMargins(for month: Date) {
        ensurePlan(for: month, provisional: false)
        let key = MonthKey(date: month)
        let monthGoals = goals.filter { $0.year == key.year && $0.month == key.month }
        let monthItems = items.filter { $0.startDate < key.interval.end && $0.endDate > key.interval.start }
        let existingMargins = monthItems.filter { $0.kind == .margin }
        let events = monthItems.filter { $0.kind != .margin }
        let baseRules = fetchBaseRules()
        let proposal = scheduler.propose(
            month: month,
            goals: monthGoals,
            events: events,
            existingMargins: existingMargins,
            baseRules: baseRules,
            notBefore: now
        )
        let undo = captureCalendarUndo(title: "余白の配置")
        do {
            proposal.slots.forEach { context.insert(CalendarItemEntity(snapshot: $0)) }
            try context.save()
            try refresh()
            finishCalendarMutation(undo)
            updateMarginRecommendation(for: month)
            recalculateBalance(for: month)
            toast = proposal.unmetGoals.isEmpty
                ? "余白をいい感じに置いたにゃ"
                : "置けなかった余白もあるので、あとで見直してにゃ"
        } catch {
            context.rollback()
            toast = "余白を配置できませんでした"
        }
    }

    func prepareEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        isImportant: Bool,
        colorTag: EventColorTag? = nil
    ) async -> CalendarItemSnapshot {
        await refreshDeviceCalendar(around: startDate, through: endDate)
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
            sourceID: nil,
            colorTag: colorTag
        )
    }

    func previewImpact(for event: CalendarItemSnapshot) -> ScheduleImpact {
        previewImpact(for: event, excludingItemID: event.id)
    }

    @discardableResult
    func commitEvent(
        _ event: CalendarItemSnapshot,
        impact: ScheduleImpact = .none,
        resolution: ImpactResolution = .exception,
        chosenRelocationDate: Date? = nil
    ) -> Bool {
        commitAdvisedEvent(event, impact: impact == .none ? previewImpact(for: event) : impact,
            resolution: resolution, chosenRelocationDate: chosenRelocationDate)
    }

    @discardableResult
    func addMargin(kind: MarginKind, on date: Date) -> Bool {
        let kind = kind.canonicalKind
        let duration = kind.defaultDurationHours
        let startHour = kind == .rest ? 9 : 13
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
        let undo = captureCalendarUndo(title: "余白の追加")
        do {
            context.insert(CalendarItemEntity(snapshot: snapshot))
            try context.save()
            try refresh()
            finishCalendarMutation(undo)
            recalculateBalance(for: date)
            return true
        } catch {
            context.rollback()
            persistenceIssue = "余白を保存できませんでした。入力を残しています。もう一度追加してください。"
            return false
        }
    }

    func moveItem(id: UUID, to date: Date) {
        do {
            guard let entity = try entity(id: id) else { return }
            guard entity.snapshot.deviceEvent == nil else {
                toast = "この予定の詳細から「カレンダーで編集」を選んでください"
                return
            }
            guard !Calendar.mira.isDate(entity.startDate, inSameDayAs: date) else { return }
            let duration = entity.endDate.timeIntervalSince(entity.startDate)
            let oldComponents = Calendar.mira.dateComponents([.hour, .minute], from: entity.startDate)
            let newStart = date.setting(hour: oldComponents.hour ?? 9, minute: oldComponents.minute ?? 0)
            var after = entity.snapshot
            after.startDate = newStart
            after.endDate = newStart.addingTimeInterval(duration)
            let impact = previewImpact(for: after, excludingItemID: id)
            let conflicts = eventEntryConflicts(for: after, excludingItemID: id)
            let preview = ChangePreview(caseID: after.conversationCaseID, itemID: id, title: after.title,
                before: entity.snapshot, after: after, conflicts: conflicts, impact: impact)
            // A drag the person made themselves is already an explicit choice:
            // only stop to ask when it would cost a margin or collide.
            if conflicts.isEmpty, impact.overlappingMargins.isEmpty, impact.protectionLevel == .flexible {
                try commitChange(preview, to: entity, undoTitle: "予定の移動")
                toast = "\(after.title)を\(newStart.japaneseShortDate)へ移したにゃ"
            } else {
                pendingChangePreview = preview
            }
        } catch {
            context.rollback()
            toast = "移動できませんでした"
        }
    }

    func deleteItem(id: UUID) {
        do {
            if let entity = try entity(id: id) {
                guard entity.snapshot.deviceEvent == nil else {
                    toast = "iPhoneの予定は、詳細の「カレンダーで編集」から削除できます"
                    return
                }
                let undo = captureCalendarUndo(title: "予定の削除")
                let affectedDate = entity.startDate
                context.delete(entity)
                try context.save()
                try refresh()
                finishCalendarMutation(undo)
                updateMarginRecommendation(for: affectedDate)
                recalculateBalance(for: affectedDate)
            }
        } catch {
            context.rollback()
            toast = "削除できませんでした"
        }
    }

    func correctLoad(itemID: UUID, to load: LoadClass, rememberKeyword: Bool) {
        do {
            guard let entity = try entity(id: itemID) else { return }
            let affectedDate = entity.startDate
            let undo = captureCalendarUndo(title: "負荷の変更")
            entity.loadRaw = load.rawValue
            entity.loadReason = "あなたが明示的に変更した負荷"
            let buffer = loadEngine.correctedBuffers(title: entity.title, load: load)
            entity.bufferBeforeMinutes = buffer.before
            entity.bufferAfterMinutes = buffer.after
            if rememberKeyword {
                context.insert(LoadRuleEntity(keyword: entity.title, loadClass: load))
            }
            try context.save()
            try refresh()
            finishCalendarMutation(undo)
            updateMarginRecommendation(for: affectedDate)
            recalculateBalance(for: affectedDate)
            toast = rememberKeyword ? "似た予定にも覚えておくにゃ" : "この予定だけ直したにゃ"
        } catch {
            context.rollback()
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
                recalculateBalance(for: MonthKey(year: goal.year, month: goal.month).firstDay)
            }
        } catch {
            context.rollback()
            toast = "目標を変更できませんでした"
        }
    }
}
