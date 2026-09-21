import Foundation

@MainActor
extension MiraStore {
    func loadDrafts() {
        do {
            let result = try draftStorage.load()
            isRestoringDrafts = true
            savedDrafts = result.archive.drafts.sorted { $0.updatedAt > $1.updatedAt }
            quickInputText = result.archive.quickInputText
            onboardingDraft = onboardingCompleted ? nil : result.archive.onboarding
            pinnedContext = result.archive.inputContext
            activeConversationCaseID = pinnedContext?.relatedCaseID
            isRestoringDrafts = false
            draftPersistenceIssue = nil
            if result.recoveredCorruption {
                toast = "下書きを読み込めませんでした。予定はそのままです。"
            }
        } catch {
            draftPersistenceIssue = "下書きを読み込めませんでした。もう一度アプリを開くと再試行します。"
            toast = draftPersistenceIssue
        }
    }

    @discardableResult
    func persistDraftArchive() -> Bool {
        guard !isRestoringDrafts else { return true }
        do {
            try draftStorage.save(DraftArchive(
                quickInputText: quickInputText,
                drafts: savedDrafts,
                onboarding: onboardingDraft,
                inputContext: pinnedContext
            ))
            draftPersistenceIssue = nil
            return true
        } catch {
            draftPersistenceIssue = "下書きを端末に保存できませんでした。入力内容はこの画面に残っています。"
            toast = draftPersistenceIssue
            return false
        }
    }

    func saveDraft(_ content: SavedDraftContent) {
        guard !isRestoringDrafts else { return }
        if let existing = savedDrafts.first(where: { $0.id == content.id }), existing.content == content {
            if draftPersistenceIssue != nil { persistDraftArchive() }
            return
        }
        savedDrafts.removeAll {
            $0.id == content.id || (content.workflowKey != nil && $0.content.workflowKey == content.workflowKey)
        }
        savedDrafts.insert(SavedMiraDraft(content: content, updatedAt: now), at: 0)
        persistDraftArchive()
    }

    /// Only call after the calendar/adjustment transaction has succeeded.
    func completeSavedDraft(id: UUID) {
        savedDrafts.removeAll { $0.id == id }
        persistDraftArchive()
    }

    func discardSavedDraft(id: UUID) {
        if activeSchedulingDraft?.id == id { activeSchedulingDraft = nil }
        if activeDeclineDraft?.id == id { activeDeclineDraft = nil }
        if pendingChangePreview?.id == id { pendingChangePreview = nil }
        if pendingEventCreationPreview?.id == id { pendingEventCreationPreview = nil }
        if activeClarification?.id == id {
            activeClarification = nil
            pendingInterpretation = nil
        }
        if presentedEventForm?.id == id { presentedEventForm = nil }
        completeSavedDraft(id: id)
    }

    func resumeSavedDraft(id: UUID) {
        guard let saved = savedDrafts.first(where: { $0.id == id }) else { return }
        switch saved.content {
        case .eventForm(let draft):
            presentedEventForm = draft
        case .scheduling(let draft, let intent):
            activeSchedulingIntent = intent
            activeConversationCaseID = draft.conversationCaseID
            activeSchedulingDraft = draft
        case .decline(let draft):
            activeConversationCaseID = draft.caseID
            activeDeclineDraft = draft
        case .change(var preview):
            guard let current = items.first(where: { $0.id == preview.itemID }) else {
                toast = "元の予定が見つかりません。下書き一覧から内容を確認・削除できます。"
                return
            }
            guard current == preview.before else {
                toast = "元の予定が変更されています。最新の予定から変更を頼み直してください。下書きは残っています。"
                return
            }
            preview.conflicts = eventEntryConflicts(for: preview.after, excludingItemID: preview.itemID)
            preview.impact = previewImpact(for: preview.after)
            activeConversationCaseID = preview.caseID
            pendingChangePreview = preview
        case .eventPreview(var preview):
            if items.contains(where: { $0.id == preview.event.id }) {
                completeSavedDraft(id: preview.id)
                toast = "この予定はすでに登録されています。"
                return
            }
            preview.conflicts = eventEntryConflicts(for: preview.event)
            preview.impact = previewImpact(for: preview.event)
            activeConversationCaseID = preview.caseID
            pendingEventCreationPreview = preview
        case .clarification(let clarification, let interpretation):
            pendingInterpretation = interpretation
            activeConversationCaseID = clarification.caseID
            activeClarification = clarification
        }
    }

    func clearAllDrafts() {
        isRestoringDrafts = true
        quickInputText = ""
        savedDrafts = []
        onboardingDraft = nil
        presentedEventForm = nil
        activeSchedulingDraft = nil
        activeDeclineDraft = nil
        pendingChangePreview = nil
        pendingEventCreationPreview = nil
        activeClarification = nil
        pendingInterpretation = nil
        pinnedContext = nil
        isRestoringDrafts = false
        persistDraftArchive()
    }
}
