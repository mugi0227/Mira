import Foundation

@MainActor
extension MiraStore {
    /// Adds the plans the person kept from a screenshot import in one step,
    /// so a single undo takes the whole import back.
    @discardableResult
    func importCandidates(_ candidates: [ImportCandidate]) -> Int {
        let chosen = candidates.filter { $0.isSelected && $0.end > $0.start }
        guard !chosen.isEmpty else { return 0 }
        let undo = captureCalendarUndo(title: "カレンダーの引っ越し")
        do {
            let rules = fetchLoadRules()
            for candidate in chosen {
                let evaluation = loadEngine.evaluate(
                    title: candidate.title,
                    startDate: candidate.start,
                    endDate: candidate.end,
                    isAllDay: candidate.isAllDay,
                    explicitRules: rules
                )
                let snapshot = CalendarItemSnapshot(
                    id: UUID(),
                    title: candidate.title,
                    startDate: candidate.start,
                    endDate: candidate.end,
                    isAllDay: candidate.isAllDay,
                    kind: .confirmed,
                    marginKind: nil,
                    loadClass: evaluation.loadClass,
                    loadReason: evaluation.reason,
                    bufferBeforeMinutes: evaluation.bufferBeforeMinutes,
                    bufferAfterMinutes: evaluation.bufferAfterMinutes,
                    isImportantTime: false,
                    sourceID: nil,
                    colorTag: candidate.colorTag
                )
                context.insert(CalendarItemEntity(snapshot: snapshot))
            }
            try context.save()
            try refresh()
            finishCalendarMutation(undo)
            let months = Set(chosen.map { MonthKey(date: $0.start) })
            for month in months {
                updateMarginRecommendation(for: month.firstDay)
                recalculateBalance(for: month.firstDay)
            }
            toast = "\(chosen.count)件の予定を引っ越したにゃ"
            return chosen.count
        } catch {
            context.rollback()
            toast = "取り込めませんでした"
            return 0
        }
    }
}
