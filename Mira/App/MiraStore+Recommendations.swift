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
            scheduler: scheduler
        )

        do {
            let existing = rebalanceProposalEntities.filter {
                Calendar.mira.isDate($0.month, equalTo: key.firstDay, toGranularity: .month)
            }

            guard let proposal else {
                existing.forEach(context.delete)
                try context.save()
                activeRebalanceProposal = nil
                try refresh()
                return
            }

            if existing.contains(where: { $0.stateHash == proposal.stateHash && !$0.isDismissed }) {
                activeRebalanceProposal = existing.first(where: { $0.stateHash == proposal.stateHash && !$0.isDismissed })?.proposal
                return
            }

            existing.forEach(context.delete)
            context.insert(RebalanceProposalEntity(proposal: proposal))
            try context.save()
            try refresh()
            activeRebalanceProposal = proposal
        } catch {
            // Rebalancing is advisory. A persistence failure must never block calendar edits.
        }
    }

    func applyRebalanceProposal(_ proposal: RebalanceProposal) {
        do {
            for move in proposal.moves {
                if let margin = items.first(where: { $0.id == move.marginItemID && $0.kind == .margin }) {
                    try moveMargin(margin, to: move.to)
                } else if let kind = marginKind(for: move.title) {
                    let duration = kind.defaultDurationHours
                    let startHour = kind == .rest ? 9 : (kind == .freeEvening || kind == .solo ? 18 : 13)
                    let start = move.to.setting(hour: startHour)
                    let end = Calendar.mira.date(byAdding: .hour, value: duration, to: start) ?? start
                    context.insert(CalendarItemEntity(snapshot: CalendarItemSnapshot(
                        id: UUID(),
                        title: kind.title,
                        startDate: start,
                        endDate: end,
                        isAllDay: kind == .rest,
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
            activeRebalanceProposal = nil
            toast = "余白の完成案を反映したにゃ"
        } catch {
            toast = "余白を組み直せませんでした"
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
