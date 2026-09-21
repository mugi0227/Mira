import Foundation
import SwiftData

struct AdjustmentUndoState: Equatable {
    var id: UUID
    var status: AdjustmentStatus
    var candidates: [CandidateSlotSnapshot]
}

struct InvitationUndoState: Equatable {
    var id: UUID
    var status: InvitationStatus
}

struct CaseUndoState: Equatable {
    var id: UUID
    var kind: ConversationCaseKind
    var status: ConversationCaseStatus
    var state: ConversationCaseState
}

struct LoadRuleUndoState: Hashable {
    var id: UUID
    var keyword: String
    var loadRaw: String
    var createdAt: Date
}

struct CalendarUndoEntry {
    var title: String
    var before: [CalendarItemSnapshot]
    var after: Set<CalendarItemSnapshot> = []
    var adjustments: [AdjustmentUndoState]
    var invitations: [InvitationUndoState]
    var cases: [CaseUndoState]
    var loadRules: [LoadRuleUndoState]?
    var afterAdjustments: [AdjustmentUndoState] = []
    var afterInvitations: [InvitationUndoState] = []
    var afterCases: [CaseUndoState] = []
    var afterLoadRules: [LoadRuleUndoState]?
}

@MainActor
extension MiraStore {
    func captureCalendarUndo(title: String) -> CalendarUndoEntry {
        CalendarUndoEntry(title: title, before: items,
            adjustments: adjustments.map { AdjustmentUndoState(id: $0.id, status: $0.status, candidates: $0.candidates) },
            invitations: pendingInvitations.map { InvitationUndoState(id: $0.id, status: $0.status) },
            cases: conversationCases.map { CaseUndoState(id: $0.id, kind: $0.kind, status: $0.status, state: $0.state) },
            loadRules: try? context.fetch(FetchDescriptor<LoadRuleEntity>()).map {
                LoadRuleUndoState(id: $0.id, keyword: $0.keyword, loadRaw: $0.loadRaw, createdAt: $0.createdAt)
            })
    }

    func finishCalendarMutation(_ entry: CalendarUndoEntry) {
        var entry = entry
        entry.after = Set(items)
        let workflow = captureCalendarUndo(title: entry.title)
        guard entry.loadRules != nil, workflow.loadRules != nil else {
            undoEntry = nil
            return
        }
        entry.afterAdjustments = workflow.adjustments
        entry.afterInvitations = workflow.invitations
        entry.afterCases = workflow.cases
        entry.afterLoadRules = workflow.loadRules
        undoEntry = entry
    }

    func undoLastCalendarMutation() async {
        guard let entry = undoEntry else { return }
        let workflow = captureCalendarUndo(title: entry.title)
        // Never overwrite an intervening import or calendar edit.
        guard let beforeRules = entry.loadRules,
              let afterRules = entry.afterLoadRules,
              let currentRules = workflow.loadRules,
              Set(currentRules) == Set(afterRules),
              Set(items) == entry.after,
              workflow.adjustments == entry.afterAdjustments,
              workflow.invitations == entry.afterInvitations,
              workflow.cases == entry.afterCases else {
            undoEntry = nil
            toast = "その後に予定が変わったため、この操作は取り消せません"
            return
        }
        do {
            let ruleEntities = try context.fetch(FetchDescriptor<LoadRuleEntity>())
            let wantedRules = Set(beforeRules.map(\.id))
            for entity in ruleEntities where !wantedRules.contains(entity.id) { context.delete(entity) }
            for value in beforeRules {
                let entity = ruleEntities.first { $0.id == value.id } ?? LoadRuleEntity(
                    id: value.id, keyword: value.keyword, loadClass: LoadClass(rawValue: value.loadRaw) ?? .normal)
                if !ruleEntities.contains(where: { $0.id == value.id }) { context.insert(entity) }
                entity.keyword = value.keyword
                entity.loadRaw = value.loadRaw
                entity.createdAt = value.createdAt
            }
            let entities = try context.fetch(FetchDescriptor<CalendarItemEntity>())
            let wanted = Set(entry.before.map(\.id))
            for entity in entities where !wanted.contains(entity.id) { context.delete(entity) }
            for snapshot in entry.before {
                if let entity = entities.first(where: { $0.id == snapshot.id }) { entity.apply(snapshot) }
                else { context.insert(CalendarItemEntity(snapshot: snapshot)) }
            }
            for value in entry.adjustments {
                guard let entity = adjustments.first(where: { $0.id == value.id }) else { continue }
                entity.status = value.status
                entity.candidates = value.candidates
            }
            for value in entry.invitations { pendingInvitations.first { $0.id == value.id }?.status = value.status }
            for value in entry.cases {
                guard let entity = conversationCase(id: value.id) else { continue }
                entity.kind = value.kind
                entity.status = value.status
                entity.state = value.state
                entity.appendTurn(role: .assistant, text: "直前の\(entry.title)を取り消しました", at: now)
            }
            try context.save()
            try refresh()
            undoEntry = nil
            updateMarginRecommendation(for: selectedMonth)
            recalculateBalance(for: selectedMonth)
            await reconcileReminders()
            toast = "\(entry.title)を取り消しました"
        } catch {
            context.rollback()
            persistenceIssue = "取り消しを保存できませんでした。もう一度お試しください。"
        }
    }

}
