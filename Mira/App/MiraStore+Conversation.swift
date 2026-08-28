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
        let activeContext = contextResult(forCaseID: activeConversationCaseID)
        let effectivePinned = pinnedContext ?? activeContext
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
                startSchedulingDraft(from: interpretation, caseEntity: caseEntity)
            }

        case .declineInvitation:
            let draft = await declineGenerator.generate(
                title: caseEntity.title,
                person: caseEntity.state.person,
                previous: nil,
                softer: false,
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
                startSchedulingDraft(from: interpretation, caseEntity: caseEntity)
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
        if let caseID = clarification.caseID {
            activeConversationCaseID = caseID
        }
        await handleConversationInput("\(clarification.originalText) \(option)")
    }

    func generateNextDeclineDraft(softer: Bool = false) async {
        guard let current = activeDeclineDraft else { return }
        let next = await declineGenerator.generate(
            title: current.title,
            person: current.person,
            previous: current.text,
            softer: softer,
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
        let start = Calendar.mira.startOfDay(for: selectedMonth)
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
        startSchedulingDraft(from: interpretation, caseEntity: caseEntity)
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
            draft.month = month
            let key = MonthKey(date: month)
            draft.dateRangeStart = max(draft.dateRangeStart, key.firstDay)
            draft.dateRangeEnd = min(draft.dateRangeEnd, key.interval.end.addingTimeInterval(-1))
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

        let candidates = selected.map(\.candidateSnapshot)
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
            updateMarginRecommendation(for: preview.after.startDate)
            recalculateBalance(for: preview.after.startDate)
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
        updateMarginRecommendation(for: preview.event.startDate)
        recalculateBalance(for: preview.event.startDate)
    }

    // MARK: - Private routing helpers

    private func resolvedAutomaticContext(from candidates: [ContextSearchResult]) -> ContextSearchResult? {
        guard let first = candidates.first else { return nil }
        let second = candidates.dropFirst().first?.score ?? 0
        return first.score >= 75 && first.score - second >= 18 ? first : nil
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

        let defaultRange = RuleBasedConversationInterpreter().defaultSearchRange(text: interpretation.title, now: now)
        let start = interpretation.dateRangeStart ?? interpretation.candidateDates.min() ?? defaultRange.start
        let end = interpretation.dateRangeEnd ?? interpretation.candidateDates.max() ?? defaultRange.end
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
            let allowedDays = Set(interpretation.candidateDates.map { Calendar.mira.startOfDay(for: $0) })
            draft.recommendations = draft.recommendations.filter { allowedDays.contains(Calendar.mira.startOfDay(for: $0.day)) }
            let recommended = draft.recommendations.sorted { $0.score > $1.score }.prefix(min(5, max(1, draft.recommendations.count)))
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

    private func makeChangePreview(
        interpretation: ConversationInterpretation,
        resolvedContext: ContextSearchResult?,
        caseEntity: ConversationCaseEntity
    ) -> ChangePreview? {
        let itemID = resolvedContext?.relatedItemID ?? caseEntity.state.relatedItemID
        guard let itemID, let before = items.first(where: { $0.id == itemID }) else { return nil }
        var after = before

        if let exactStart = interpretation.exactStartDate {
            let oldDuration = max(30 * 60, before.endDate.timeIntervalSince(before.startDate))
            after.startDate = exactStart
            after.endDate = interpretation.exactEndDate ?? exactStart.addingTimeInterval(oldDuration)
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

        let conflicts = eventEntryConflicts(for: after).filter { message in
            if message.contains(before.title) { return false }
            return true
        }
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
