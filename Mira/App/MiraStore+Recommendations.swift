import Foundation
import SwiftData

@MainActor
extension MiraStore {
    func updateMarginRecommendation(for month: Date) {
        currentMarginRecommendation = marginRecommendationEngine.recommend(
            month: month,
            items: items,
            comfort: marginComfortLevel
        )
    }

    func applyCurrentMarginRecommendation() {
        guard let recommendation = currentMarginRecommendation else { return }
        let key = MonthKey(date: recommendation.month)
        do {
            let existing = try context.fetch(FetchDescriptor<MarginGoalEntity>())
                .filter { $0.year == key.year && $0.month == key.month }
            for (kind, target) in recommendation.targets {
                if let entity = existing.first(where: { $0.kindRaw == kind.rawValue }) {
                    entity.targetCount = target
                    entity.isEnabled = target > 0
                    entity.durationHours = kind.defaultDurationHours
                    entity.priority = kind.defaultPriority
                } else {
                    context.insert(MarginGoalEntity(snapshot: MarginGoalSnapshot(
                        id: UUID(),
                        year: key.year,
                        month: key.month,
                        kind: kind,
                        targetCount: target,
                        durationHours: kind.defaultDurationHours,
                        priority: kind.defaultPriority,
                        isEnabled: target > 0
                    )))
                }
            }
            try context.save()
            try refresh()
            autoPlaceMargins(for: recommendation.month)
            toast = "予定負荷に合わせて余白を組んだにゃ"
        } catch {
            toast = "おすすめ余白を反映できませんでした"
        }
    }

    func recalculateBalance(for month: Date) {
        let key = MonthKey(date: month)
        let monthGoals = goals.filter { $0.year == key.year && $0.month == key.month }
        let proposal = rebalanceEngine.propose(
            month: month,
            items: items,
            goals: monthGoals,
            baseRules: fetchBaseRules(),
            scheduler: scheduler,
            notBefore: now
        )

        do {
            let existing = rebalanceProposalEntities.filter {
                Calendar.mira.isDate($0.month, equalTo: key.firstDay, toGranularity: .month)
            }

            guard let proposal else {
                for entity in existing { context.delete(entity) }
                try context.save()
                activeRebalanceProposal = nil
                try refresh()
                return
            }

            if let current = existing.first(where: {
                !$0.isDismissed && $0.proposal.map { rebalanceEngine.matches($0, proposal, items: items) } == true
            }) {
                activeRebalanceProposal = current.proposal
                return
            }

            for entity in existing { context.delete(entity) }
            context.insert(RebalanceProposalEntity(proposal: proposal))
            try context.save()
            try refresh()
            activeRebalanceProposal = proposal
        } catch {
            context.rollback()
            // Rebalancing is advisory. A persistence failure must never block calendar edits.
        }
    }

    @discardableResult
    func applyRebalanceProposal(_ proposal: RebalanceProposal) -> Bool {
        do {
            try refresh()
            let key = MonthKey(date: proposal.month)
            let baseRules = try context.fetch(FetchDescriptor<BaseRuleEntity>()).map(\.snapshot)
            let current = rebalanceEngine.propose(
                month: proposal.month, items: items,
                goals: goals.filter { $0.year == key.year && $0.month == key.month },
                baseRules: baseRules, scheduler: scheduler, notBefore: now
            )
            let stored = rebalanceProposalEntities.first { $0.id == proposal.id && !$0.isDismissed }?.proposal
            guard let current, let stored,
                  rebalanceEngine.matches(proposal, stored, items: items),
                  rebalanceEngine.matches(proposal, current, items: items) else {
                recalculateBalance(for: proposal.month)
                if activeRebalanceProposal == nil {
                    // Keep the review open even when the elapsed time leaves no
                    // feasible replacement; the user can explicitly close it.
                    activeRebalanceProposal = proposal
                    toast = "状況が変わり、今は再配置できる候補がありません"
                } else {
                    toast = "予定や時間が変わったため、提案を更新しました。もう一度確認してください"
                }
                return false
            }
            let undo = captureCalendarUndo(title: "余白の再配置")
            for move in proposal.moves {
                if let margin = items.first(where: { $0.id == move.marginItemID && $0.kind == .margin }) {
                    try moveMargin(margin, to: move.to)
                } else {
                    guard let kind = move.marginKind, let duration = move.durationSeconds,
                          duration.isFinite, duration > 0, let isAllDay = move.isAllDay else {
                        throw RebalanceApplicationError.invalidInterval
                    }
                    let start = move.to
                    let end = start.addingTimeInterval(duration)
                    context.insert(CalendarItemEntity(snapshot: CalendarItemSnapshot(
                        id: move.marginItemID,
                        title: move.title,
                        startDate: start,
                        endDate: end,
                        isAllDay: isAllDay,
                        kind: .margin,
                        marginKind: kind,
                        loadClass: .light,
                        loadReason: "Miraの再設計案で戻した余白",
                        bufferBeforeMinutes: 0,
                        bufferAfterMinutes: 0,
                        isImportantTime: false,
                        sourceID: proposal.id
                    )))
                }
            }
            if let entity = rebalanceProposalEntities.first(where: { $0.id == proposal.id }) {
                context.delete(entity)
            }
            try context.save()
            try refresh()
            finishCalendarMutation(undo)
            activeRebalanceProposal = nil
            toast = "余白の完成案を反映したにゃ"
            return true
        } catch {
            context.rollback()
            try? refresh()
            if activeRebalanceProposal == nil { activeRebalanceProposal = proposal }
            toast = "余白を組み直せませんでした"
            return false
        }
    }

    func dismissRebalanceProposal(_ proposal: RebalanceProposal) {
        guard let entity = rebalanceProposalEntities.first(where: { $0.id == proposal.id }) else {
            activeRebalanceProposal = nil
            return
        }
        entity.isDismissed = true
        entity.updatedAt = .now
        try? context.save()
        try? refresh()
        activeRebalanceProposal = nil
    }
}

private enum RebalanceApplicationError: Error {
    case invalidInterval
}
