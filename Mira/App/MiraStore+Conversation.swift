import Foundation
import SwiftData

@MainActor
extension MiraStore {
    func searchContexts(
        query: String = "",
        kind: ConversationCaseKind? = nil,
        includePast: Bool = false,
        limit: Int = 30
    ) -> [ContextSearchResult] {
        caseSearchEngine.search(
            query: query,
            includePast: includePast,
            now: now,
            cases: conversationCases,
            items: items,
            adjustments: adjustments,
            invitations: pendingInvitations,
            kindFilter: kind,
            limit: limit
        )
    }

    func pinContext(_ result: ContextSearchResult?) {
        pinnedContext = result
        activeConversationCaseID = result?.relatedCaseID
    }

    func conversationTurns(caseID: UUID?) -> [ConversationTurnSnapshot] {
        conversationCase(id: caseID)?.turns ?? []
    }

    func handleConversationInput(_ rawText: String) async {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isInterpretingConversation else { return }

        isInterpretingConversation = true
        defer { isInterpretingConversation = false }

        let automaticCandidates = caseSearchEngine.automaticCandidates(
            for: text,
            now: now,
            cases: conversationCases,
            items: items,
            adjustments: adjustments,
            invitations: pendingInvitations
        )
        let continuationContext = shouldContinueActiveConversation(for: text)
            ? contextResult(forCaseID: activeConversationCaseID)
            : nil
        let effectivePinned = pinnedContext ?? continuationContext
        let recentTurns = conversationCase(id: effectivePinned?.relatedCaseID)?.turns ?? []

        let interpretation = await conversationInterpreter.interpret(
            text: text,
            now: now,
            pinnedContext: effectivePinned,
            searchCandidates: automaticCandidates,
            recentTurns: recentTurns
        )
        pendingInterpretation = interpretation

        let resolvedContext = effectivePinned ?? resolvedAutomaticContext(from: automaticCandidates)
        let caseEntity = ensureConversationCase(
            interpretation: interpretation,
            resolvedContext: resolvedContext
        )
        activeConversationCaseID = caseEntity.id
        caseEntity.appendTurn(role: .user, text: text, at: now)
        try? context.save()

        switch interpretation.intent {
        case .findDates, .checkInvitation:
            if interpretation.needsClarification || interpretation.durationBucket == nil || interpretation.timeBands.isEmpty {
                presentClarification(for: interpretation, originalText: text, caseEntity: caseEntity)
            } else {
                startSchedulingDraft(from: interpretation, originalText: text, caseEntity: caseEntity)
            }

        case .declineInvitation:
            let draft = await declineGenerator.generate(
                title: caseEntity.title,
                person: caseEntity.state.person,
                previous: nil,
                softer: false,
                audience: .friend,
                generationIndex: 0
            )
            var value = draft
            value.caseID = caseEntity.id
            activeDeclineDraft = value
            caseEntity.appendTurn(role: .assistant, text: value.text, at: now)
            try? context.save()
            try? refresh()

        case .updateExisting:
            if let preview = makeChangePreview(
                interpretation: interpretation,
                resolvedContext: resolvedContext,
                caseEntity: caseEntity
            ) {
                pendingChangePreview = preview
                caseEntity.appendTurn(role: .assistant, text: "変更前と変更後を確認してにゃ", at: now)
            } else {
                activeClarification = ConversationClarification(
                    caseID: caseEntity.id,
                    question: "どの予定を変更する？",
                    options: automaticCandidates.prefix(3).map(\.title),
                    originalText: text
                )
                caseEntity.appendTurn(role: .assistant, text: "変更する予定を選んでにゃ", at: now)
            }
            try? context.save()

        case .addEvent:
            if let preview = await makeEventCreationPreview(
                interpretation: interpretation,
                caseEntity: caseEntity
            ) {
                pendingEventCreationPreview = preview
                caseEntity.appendTurn(role: .assistant, text: "追加する予定を確認してにゃ", at: now)
                try? context.save()
            } else if interpretation.durationBucket != nil, !interpretation.timeBands.isEmpty {
                startSchedulingDraft(from: interpretation, originalText: text, caseEntity: caseEntity)
            } else {
                presentClarification(for: interpretation, originalText: text, caseEntity: caseEntity)
            }

        case .askAboutExisting:
            let reply = summaryReply(for: resolvedContext, caseEntity: caseEntity)
            caseEntity.appendTurn(role: .assistant, text: reply, at: now)
            toast = reply
            try? context.save()
            try? refresh()

        case .unknown:
            presentClarification(for: interpretation, originalText: text, caseEntity: caseEntity)
        }
    }

    func answerClarification(_ option: String) async {
        guard let clarification = activeClarification else { return }
        activeClarification = nil
        let previousPinned = pinnedContext
        if let caseID = clarification.caseID {
            activeConversationCaseID = caseID
            if pinnedContext == nil {
                pinnedContext = contextResult(forCaseID: caseID)
            }
        }
        await handleConversationInput("\(clarification.originalText) \(option)")
        if previousPinned == nil {
            pinnedContext = nil
        }
    }

    func generateNextDeclineDraft(softer: Bool = false, audience: DeclineAudience? = nil) async {
        guard let current = activeDeclineDraft else { return }
        let resolvedAudience = audience ?? current.audience
        let next = await declineGenerator.generate(
            title: current.title,
            person: current.person,
            previous: current.text,
            softer: softer,
            audience: resolvedAudience,
            generationIndex: current.generationIndex + 1
        )
        var value = next
        value.caseID = current.caseID
        activeDeclineDraft = value
        if let entity = conversationCase(id: current.caseID) {
            entity.appendTurn(role: .assistant, text: value.text, at: now)
            try? context.save()
            try? refresh()
        }
    }

    func startManualScheduling() {
        let start = max(Calendar.mira.startOfDay(for: selectedMonth), Calendar.mira.startOfDay(for: now))
        let end = start.addingDays(28)
        let interpretation = ConversationInterpretation(
            intent: .findDates,
            title: "新しい日程調整",
            person: nil,
            candidateDates: [],
            dateRangeStart: start,
            dateRangeEnd: end,
            durationBucket: .short,
            timeBands: [.morning, .midday, .evening],
            exactStartDate: nil,
            exactEndDate: nil,
            inferredFields: [],
            explicitConstraints: [],
            needsClarification: false,
            clarificationQuestion: nil,
            clarificationOptions: [],
            matchedContextID: nil,
            confidence: 1,
            source: "手動入口"
        )
        let caseEntity = ConversationCaseEntity(
            title: interpretation.title,
            kind: .draft,
            state: ConversationCaseState(
                dateRangeStart: start,
                dateRangeEnd: end,
                durationBucket: .short,
                allowedTimeBands: interpretation.timeBands,
                lastIntent: .findDates
            )
        )
        context.insert(caseEntity)
        try? context.save()
        try? refresh()
        activeConversationCaseID = caseEntity.id
        startSchedulingDraft(from: interpretation, originalText: interpretation.title, caseEntity: caseEntity)
    }

    func startScheduling(for session: AdjustmentEntity) {
        let start = Calendar.mira.startOfDay(for: now)
        let end = start.addingDays(28)
        let caseEntity: ConversationCaseEntity

        if let existing = conversationCase(id: session.conversationCaseID) {
            caseEntity = existing
        } else {
            let created = ConversationCaseEntity(
                title: session.title,
                kind: .adjustment,
                status: .waiting,
                state: ConversationCaseState(
                    relatedAdjustmentID: session.id,
                    person: session.contactName,
                    dateRangeStart: start,
                    dateRangeEnd: end,
                    durationBucket: .short,
                    allowedTimeBands: [.morning, .midday, .evening],
                    lastIntent: .findDates
                )
            )
            context.insert(created)
            session.conversationCaseID = created.id
            try? context.save()
            try? refresh()
            caseEntity = conversationCase(id: created.id) ?? created
        }

        var state = caseEntity.state
        state.relatedAdjustmentID = session.id
        caseEntity.state = state
        activeConversationCaseID = caseEntity.id
        activeSchedulingIntent = .findDates

        let interpretation = ConversationInterpretation(
            intent: .findDates,
            title: session.title,
            person: session.contactName,
            candidateDates: [],
            dateRangeStart: start,
            dateRangeEnd: end,
            durationBucket: .short,
            timeBands: [.morning, .midday, .evening],
            exactStartDate: nil,
            exactEndDate: nil,
            inferredFields: [],
            explicitConstraints: [],
            needsClarification: false,
            clarificationQuestion: nil,
            clarificationOptions: [],
            matchedContextID: caseEntity.id,
            confidence: 1,
            source: "調整中から候補を追加"
        )
        startSchedulingDraft(from: interpretation, originalText: session.title, caseEntity: caseEntity)
    }

    func updateSchedulingDraft(
        duration: DurationBucket? = nil,
        timeBands: [SchedulingTimeBand]? = nil,
        month: Date? = nil
    ) {
        guard var draft = activeSchedulingDraft else { return }
        if let duration {
            draft.durationBucket = duration
            let allowed = duration.selectableBands
            let retained = draft.timeBands.filter(allowed.contains)
            draft.timeBands = retained.isEmpty ? allowed : retained
            draft.inferredFields.remove("duration")
        }
        if let timeBands {
            draft.timeBands = timeBands.isEmpty ? draft.durationBucket.selectableBands : timeBands
            draft.inferredFields.remove("timeBands")
        }
        if let month {
            let key = MonthKey(date: month)
            draft.month = key.firstDay
            draft.dateRangeStart = max(key.firstDay, Calendar.mira.startOfDay(for: now))
            draft.dateRangeEnd = key.interval.end.addingTimeInterval(-1)
            if draft.dateRangeStart > draft.dateRangeEnd {
                draft.dateRangeStart = key.firstDay
            }
        }
        activeSchedulingDraft = recommendations(for: draft, preserveManualSelection: false)
    }

    func toggleSchedulingCandidate(_ recommendationID: UUID, allowConflict: Bool = false) {
        guard var draft = activeSchedulingDraft,
              let candidate = draft.recommendations.first(where: { $0.id == recommendationID }) else { return }
        if !candidate.conflicts.isEmpty, !allowConflict,
           !draft.selectedRecommendationIDs.contains(recommendationID) {
            toast = candidate.conflicts.joined(separator: "。") + "。それでも選ぶならもう一度押してにゃ"
            return
        }
        if draft.selectedRecommendationIDs.contains(recommendationID) {
            draft.selectedRecommendationIDs.remove(recommendationID)
        } else {
            draft.selectedRecommendationIDs.insert(recommendationID)
        }
        activeSchedulingDraft = draft
    }

    func clearRecommendedSchedulingCandidates() {
        guard var draft = activeSchedulingDraft else { return }
        let recommendationIDs = Set(draft.recommendations.filter(\.isRecommended).map(\.id))
        draft.selectedRecommendationIDs.subtract(recommendationIDs)
        activeSchedulingDraft = draft
    }

    func commitSchedulingDraft() {
        guard let draft = activeSchedulingDraft else { return }
        let selected = draft.selectedRecommendations.sorted {
            if $0.day != $1.day { return $0.day < $1.day }
            return $0.timeBand.rawValue < $1.timeBand.rawValue
        }
        guard !selected.isEmpty else {
            toast = "候補を1つ以上選んでにゃ"
            return
        }

        let candidates = selected.map { candidateSnapshot(from: $0, draft: draft) }
        let message = DemoSeeder.message(title: draft.title, candidates: candidates)
        let caseEntity = conversationCase(id: draft.conversationCaseID)

        if activeSchedulingIntent == .checkInvitation {
            let entity = PendingInvitationEntity(
                title: draft.title,
                contactName: draft.person,
                status: .considering,
                candidates: candidates,
                conversationCaseID: caseEntity?.id
            )
            context.insert(entity)
            if let caseEntity {
                caseEntity.kind = .invitation
                caseEntity.status = .active
                var state = caseEntity.state
                state.relatedInvitationID = entity.id
                state.candidates = candidates
                state.durationBucket = draft.durationBucket
                state.allowedTimeBands = draft.timeBands
                caseEntity.state = state
                caseEntity.appendTurn(role: .assistant, text: "候補を整理したにゃ。参加するか、別の日を探すか決められるよ。", at: now)
            }
        } else if let adjustmentID = caseEntity?.state.relatedAdjustmentID,
                  let existing = adjustments.first(where: { $0.id == adjustmentID }) {
            existing.title = draft.title
            existing.contactName = draft.person
            existing.status = .waiting
            existing.candidates = candidates
            existing.generatedMessage = message
            if let caseEntity {
                caseEntity.kind = .adjustment
                caseEntity.status = .waiting
                var state = caseEntity.state
                state.candidates = candidates
                state.durationBucket = draft.durationBucket
                state.allowedTimeBands = draft.timeBands
                caseEntity.state = state
                caseEntity.appendTurn(role: .assistant, text: "候補日を追加して仮押さえしたにゃ。", at: now)
            }
        } else {
            let entity = AdjustmentEntity(
                title: draft.title,
                contactName: draft.person,
                status: .waiting,
                candidates: candidates,
                generatedMessage: message,
                conversationCaseID: caseEntity?.id
            )
            context.insert(entity)
            if let caseEntity {
                caseEntity.kind = .adjustment
                caseEntity.status = .waiting
                var state = caseEntity.state
                state.relatedAdjustmentID = entity.id
                state.candidates = candidates
                state.durationBucket = draft.durationBucket
                state.allowedTimeBands = draft.timeBands
                caseEntity.state = state
                caseEntity.appendTurn(role: .assistant, text: "この候補を仮押さえしたにゃ。相手へ送る文も作ったよ。", at: now)
            }
        }

        do {
            try context.save()
            try refresh()
            activeSchedulingDraft = nil
            pinnedContext = nil
            toast = "候補を仮押さえしたにゃ"
        } catch {
            toast = "日程調整を保存できませんでした"
        }
    }

    func applyChangePreview() {
        guard let preview = pendingChangePreview else { return }
        do {
            guard let entity = try entity(id: preview.itemID) else { return }
            let previousDate = preview.before.startDate
            entity.apply(preview.after)
            if let caseEntity = conversationCase(id: preview.caseID) {
                caseEntity.appendTurn(role: .assistant, text: "変更を保存したにゃ", at: now)
                var state = caseEntity.state
                state.dateRangeStart = preview.after.startDate
                state.dateRangeEnd = preview.after.endDate
                state.durationBucket = preview.after.durationBucket
                state.allowedTimeBands = preview.after.schedulingTimeBand.map { [$0] } ?? []
                caseEntity.state = state
            }
            try context.save()
            try refresh()
            pendingChangePreview = nil
            updateMarginRecommendation(for: previousDate)
            updateMarginRecommendation(for: preview.after.startDate)
            recalculateBalance(for: previousDate)
            if !Calendar.mira.isDate(previousDate, equalTo: preview.after.startDate, toGranularity: .month) {
                recalculateBalance(for: preview.after.startDate)
            }
            toast = "変更を保存したにゃ"
        } catch {
            toast = "変更を保存できませんでした"
        }
    }

    func applyEventCreationPreview(resolution: ImpactResolution, relocationDate: Date? = nil) {
        guard let preview = pendingEventCreationPreview else { return }
        commitAdvisedEvent(
            preview.event,
            impact: preview.impact,
            resolution: resolution,
            chosenRelocationDate: relocationDate
        )
        if let caseEntity = conversationCase(id: preview.caseID) {
            caseEntity.kind = .confirmedEvent
            caseEntity.status = .confirmed
            var state = caseEntity.state
            state.relatedItemID = preview.event.id
            state.dateRangeStart = preview.event.startDate
            state.dateRangeEnd = preview.event.endDate
            state.durationBucket = preview.event.durationBucket
            state.allowedTimeBands = preview.event.schedulingTimeBand.map { [$0] } ?? []
            caseEntity.state = state
            caseEntity.appendTurn(role: .assistant, text: "予定を追加したにゃ", at: now)
            try? context.save()
            try? refresh()
        }
        pendingEventCreationPreview = nil
    }

    // MARK: - Private routing helpers

    private func resolvedAutomaticContext(from candidates: [ContextSearchResult]) -> ContextSearchResult? {
        guard let first = candidates.first else { return nil }
        let second = candidates.dropFirst().first?.score ?? 0
        return first.score >= 75 && first.score - second >= 18 ? first : nil
    }

    private func shouldContinueActiveConversation(for text: String) -> Bool {
        guard pinnedContext == nil,
              let active = conversationCase(id: activeConversationCaseID),
              now.timeIntervalSince(active.lastActivityAt) < 7 * 24 * 60 * 60,
              text.count <= 48 else { return false }
        let cues = [
            "夜は", "昼は", "朝は", "夜なし", "昼なし", "朝なし", "土曜", "日曜", "平日",
            "やっぱ", "じゃあ", "それで", "その件", "この件", "候補", "断る文", "柔らかく",
            "来週なら", "別の日", "時間は", "何時", "なしで", "外して"
        ]
        return cues.contains(where: text.contains)
    }

    private func contextResult(forCaseID caseID: UUID?) -> ContextSearchResult? {
        guard let entity = conversationCase(id: caseID) else { return nil }
        let state = entity.state
        return ContextSearchResult(
            id: entity.id,
            kind: entity.kind,
            title: entity.title,
            subtitle: entity.kind.title,
            startDate: state.dateRangeStart,
            endDate: state.dateRangeEnd,
            relatedCaseID: entity.id,
            relatedItemID: state.relatedItemID,
            relatedAdjustmentID: state.relatedAdjustmentID,
            relatedInvitationID: state.relatedInvitationID,
            score: 200,
            isPast: state.dateRangeEnd.map { $0 < now } ?? false
        )
    }

    private func ensureConversationCase(
        interpretation: ConversationInterpretation,
        resolvedContext: ContextSearchResult?
    ) -> ConversationCaseEntity {
        if let caseID = resolvedContext?.relatedCaseID,
           let existing = conversationCase(id: caseID) {
            return existing
        }
        if let active = conversationCase(id: activeConversationCaseID), pinnedContext != nil {
            return active
        }

        let kind: ConversationCaseKind
        switch interpretation.intent {
        case .findDates: kind = .adjustment
        case .checkInvitation, .declineInvitation: kind = .invitation
        case .updateExisting, .askAboutExisting: kind = resolvedContext?.kind ?? .confirmedEvent
        case .addEvent: kind = .draft
        case .unknown: kind = .draft
        }
        let state = ConversationCaseState(
            relatedItemID: resolvedContext?.relatedItemID,
            relatedAdjustmentID: resolvedContext?.relatedAdjustmentID,
            relatedInvitationID: resolvedContext?.relatedInvitationID,
            person: interpretation.person,
            dateRangeStart: interpretation.dateRangeStart,
            dateRangeEnd: interpretation.dateRangeEnd,
            durationBucket: interpretation.durationBucket,
            allowedTimeBands: interpretation.timeBands,
            explicitConstraints: interpretation.explicitConstraints,
            candidates: [],
            lastIntent: interpretation.intent
        )
        let entity = ConversationCaseEntity(
            title: resolvedContext?.title ?? interpretation.title,
            kind: kind,
            state: state
        )
        context.insert(entity)
        try? context.save()
        try? refresh()
        return conversationCase(id: entity.id) ?? entity
    }

    private func presentClarification(
        for interpretation: ConversationInterpretation,
        originalText: String,
        caseEntity: ConversationCaseEntity
    ) {
        let question = interpretation.clarificationQuestion ?? "どのくらいの予定になりそう？"
        let options = interpretation.clarificationOptions.isEmpty
            ? DurationBucket.allCases.map(\.title)
            : interpretation.clarificationOptions
        activeClarification = ConversationClarification(
            caseID: caseEntity.id,
            question: question,
            options: options,
            originalText: originalText
        )
        caseEntity.appendTurn(role: .assistant, text: question, at: now)
        try? context.save()
        try? refresh()
    }

    private func startSchedulingDraft(
        from interpretation: ConversationInterpretation,
        originalText: String,
        caseEntity: ConversationCaseEntity
    ) {
        guard let duration = interpretation.durationBucket else { return }
        var bands = interpretation.timeBands.isEmpty ? duration.selectableBands : interpretation.timeBands
        if interpretation.explicitConstraints.contains(where: { $0.contains("夜を除外") }) {
            bands.removeAll { $0 == .evening }
        }
        if bands.isEmpty {
            activeClarification = ConversationClarification(
                caseID: caseEntity.id,
                question: "朝・昼・夜のどこなら行けそう？",
                options: duration.selectableBands.map(\.title),
                originalText: interpretation.title
            )
            return
        }

        let defaultRange = RuleBasedConversationInterpreter().defaultSearchRange(text: originalText, now: now)
        let shouldUseFullPeriod = shouldExpandSchedulingPeriod(for: originalText)
        let start = shouldUseFullPeriod
            ? defaultRange.start
            : interpretation.dateRangeStart ?? interpretation.candidateDates.min() ?? defaultRange.start
        let end = shouldUseFullPeriod
            ? defaultRange.end
            : interpretation.dateRangeEnd ?? interpretation.candidateDates.max() ?? defaultRange.end
        var draft = SchedulingDraft(
            conversationCaseID: caseEntity.id,
            title: caseEntity.title,
            person: interpretation.person ?? caseEntity.state.person,
            month: MonthKey(date: start).firstDay,
            dateRangeStart: start,
            dateRangeEnd: max(start, end),
            durationBucket: duration,
            timeBands: bands,
            inferredFields: interpretation.inferredFields
        )
        draft = recommendations(for: draft, preserveManualSelection: false)

        if !interpretation.candidateDates.isEmpty {
            let preferredDays = Set(interpretation.candidateDates.map { Calendar.mira.startOfDay(for: $0) })
            let preferred = draft.recommendations
                .filter { preferredDays.contains(Calendar.mira.startOfDay(for: $0.day)) }
                .sorted { $0.score > $1.score }
            let source = preferred.isEmpty
                ? draft.recommendations.sorted { $0.score > $1.score }
                : preferred
            let recommended = source.prefix(min(5, max(1, source.count)))
            let recommendedIDs = Set(recommended.map(\.id))
            draft.recommendations = draft.recommendations.map { candidate in
                var copy = candidate
                copy.isRecommended = recommendedIDs.contains(candidate.id)
                return copy
            }
            draft.selectedRecommendationIDs = recommendedIDs
        }

        activeSchedulingIntent = interpretation.intent
        activeSchedulingDraft = draft
        selectedMonth = draft.month
        selectedDate = draft.dateRangeStart

        var state = caseEntity.state
        state.dateRangeStart = draft.dateRangeStart
        state.dateRangeEnd = draft.dateRangeEnd
        state.durationBucket = duration
        state.allowedTimeBands = bands
        state.lastIntent = interpretation.intent
        caseEntity.state = state
        caseEntity.appendTurn(role: .assistant, text: "良さそうな候補を先に選んだにゃ。違うところだけ直してね。", at: now)
        try? context.save()
        try? refresh()
    }

    /// Broad requests such as "来週どこかで" describe a search period, not a
    /// whitelist. Model-suggested dates inside that period remain highlighted,
    /// while every day stays available for the user to choose.
    private func shouldExpandSchedulingPeriod(for text: String) -> Bool {
        let broadTokens = ["どこか", "いつか", "今週", "来週", "再来週", "今月", "来月"]
        guard broadTokens.contains(where: text.contains) else { return false }

        let relativeSpecificDates = ["今日", "明日", "明後日"]
        guard !relativeSpecificDates.contains(where: text.contains) else { return false }

        let explicitDayPattern = #"(?:月|火|水|木|金|土|日)(?:曜|曜日)|\d{1,2}\s*(?:月|/|\.|-)\s*\d{1,2}"#
        return text.range(of: explicitDayPattern, options: .regularExpression) == nil
    }

    private func recommendations(
        for draft: SchedulingDraft,
        preserveManualSelection: Bool
    ) -> SchedulingDraft {
        var value = draft
        let held = adjustments
            .filter { $0.status == .draft || $0.status == .waiting }
            .flatMap(\.candidates)
        let range = DateInterval(start: draft.dateRangeStart, end: draft.dateRangeEnd)
        let candidates = schedulingRecommendationEngine.recommendations(
            title: draft.title,
            dateRange: range,
            duration: draft.durationBucket,
            timeBands: draft.timeBands,
            items: items,
            heldCandidates: held,
            baseRules: fetchBaseRules()
        )
        let recommendedIDs = Set(candidates.filter(\.isRecommended).map(\.id))
        if preserveManualSelection {
            let oldSelectedKeys = Set(draft.selectedRecommendations.map { selectionKey(day: $0.day, band: $0.timeBand) })
            let retained = candidates.filter { oldSelectedKeys.contains(selectionKey(day: $0.day, band: $0.timeBand)) }.map(\.id)
            value.selectedRecommendationIDs = Set(retained).union(recommendedIDs)
        } else {
            value.selectedRecommendationIDs = recommendedIDs
        }
        value.recommendations = candidates
        return value
    }

    private func selectionKey(day: Date, band: SchedulingTimeBand) -> String {
        "\(Int(Calendar.mira.startOfDay(for: day).timeIntervalSince1970))-\(band.rawValue)"
    }

    private func candidateSnapshot(
        from recommendation: CandidateRecommendation,
        draft: SchedulingDraft
    ) -> CandidateSlotSnapshot {
        var candidate = recommendation.candidateSnapshot
        guard draft.detailedTimeEnabled,
              let hour = draft.detailedStartHour else { return candidate }
        let minute = draft.detailedStartMinute ?? 0
        let start = recommendation.day.setting(hour: hour, minute: minute)
        candidate.startDate = start
        candidate.endDate = start.addingTimeInterval(TimeInterval(draft.durationBucket.representativeMinutes * 60))
        candidate.exactTimeKnown = true
        candidate.schedulingTimeBand = schedulingBand(for: start)
        return candidate
    }

    private func makeChangePreview(
        interpretation: ConversationInterpretation,
        resolvedContext: ContextSearchResult?,
        caseEntity: ConversationCaseEntity
    ) -> ChangePreview? {
        let itemID = resolvedContext?.relatedItemID ?? caseEntity.state.relatedItemID
        guard let itemID, let before = items.first(where: { $0.id == itemID }) else { return nil }
        var after = before

        if let parsedStart = interpretation.exactStartDate {
            let oldDuration = max(30 * 60, before.endDate.timeIntervalSince(before.startDate))
            let exactStart: Date
            if interpretation.candidateDates.isEmpty {
                let components = Calendar.mira.dateComponents([.hour, .minute], from: parsedStart)
                exactStart = before.startDate.setting(
                    hour: components.hour ?? Calendar.mira.component(.hour, from: before.startDate),
                    minute: components.minute ?? 0
                )
            } else {
                exactStart = parsedStart
            }
            after.startDate = exactStart
            after.endDate = interpretation.exactEndDate.map { parsedEnd in
                if interpretation.candidateDates.isEmpty {
                    let components = Calendar.mira.dateComponents([.hour, .minute], from: parsedEnd)
                    return before.startDate.setting(hour: components.hour ?? 21, minute: components.minute ?? 0)
                }
                return parsedEnd
            } ?? exactStart.addingTimeInterval(oldDuration)
            after.exactTimeKnown = true
            after.schedulingTimeBand = schedulingBand(for: exactStart)
        } else if let date = interpretation.candidateDates.first {
            let band = interpretation.timeBands.first ?? before.schedulingTimeBand ?? schedulingBand(for: before.startDate)
            let duration = interpretation.durationBucket ?? before.durationBucket ?? .short
            let interval = band.representativeInterval(on: date, duration: duration)
            after.startDate = interval.start
            after.endDate = interval.end
            after.schedulingTimeBand = band
            after.durationBucket = duration
            after.exactTimeKnown = false
        }

        let conflicts = eventEntryConflicts(for: after, excludingItemID: before.id)
        return ChangePreview(
            caseID: caseEntity.id,
            itemID: itemID,
            title: before.title,
            before: before,
            after: after,
            conflicts: conflicts,
            impact: previewImpact(for: after)
        )
    }

    private func makeEventCreationPreview(
        interpretation: ConversationInterpretation,
        caseEntity: ConversationCaseEntity
    ) async -> EventCreationPreview? {
        let start: Date
        let end: Date
        let exactKnown: Bool
        let band: SchedulingTimeBand?
        let duration = interpretation.durationBucket ?? .short

        if let exactStart = interpretation.exactStartDate {
            start = exactStart
            end = interpretation.exactEndDate ?? exactStart.addingTimeInterval(TimeInterval(duration.representativeMinutes * 60))
            exactKnown = true
            band = schedulingBand(for: exactStart)
        } else if let date = interpretation.candidateDates.first {
            let selectedBand = interpretation.timeBands.first ?? duration.selectableBands.first ?? .midday
            let interval = selectedBand.representativeInterval(on: date, duration: duration)
            start = interval.start
            end = interval.end
            exactKnown = false
            band = selectedBand
        } else {
            return nil
        }

        var event = await prepareEvent(
            title: caseEntity.title,
            startDate: start,
            endDate: end,
            isAllDay: duration == .fullDay,
            isImportant: false
        )
        event.schedulingTimeBand = band
        event.durationBucket = duration
        event.exactTimeKnown = exactKnown
        event.conversationCaseID = caseEntity.id
        return EventCreationPreview(
            caseID: caseEntity.id,
            event: event,
            conflicts: eventEntryConflicts(for: event),
            impact: previewImpact(for: event)
        )
    }

    private func schedulingBand(for date: Date) -> SchedulingTimeBand {
        let hour = Calendar.mira.component(.hour, from: date)
        switch hour {
        case ..<12: return .morning
        case 12..<17: return .midday
        default: return .evening
        }
    }

    private func summaryReply(
        for context: ContextSearchResult?,
        caseEntity: ConversationCaseEntity
    ) -> String {
        guard let context else { return "どの予定のことか、左のボタンから選べるにゃ" }
        if let itemID = context.relatedItemID,
           let item = items.first(where: { $0.id == itemID }) {
            return "\(item.title)は\(item.startDate.japaneseShortDate)の\(item.timeDescription)。負荷は\(item.loadClass.title)です。"
        }
        if let adjustmentID = context.relatedAdjustmentID,
           let adjustment = adjustments.first(where: { $0.id == adjustmentID }) {
            return "\(adjustment.title)は候補\(adjustment.candidates.count)件で返事待ちです。"
        }
        if let invitationID = context.relatedInvitationID,
           let invitation = pendingInvitations.first(where: { $0.id == invitationID }) {
            return "\(invitation.title)はまだ検討中です。参加した場合の余白も確認できます。"
        }
        return "\(caseEntity.title)について続けられるにゃ"
    }
}
