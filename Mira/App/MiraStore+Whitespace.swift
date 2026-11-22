import Foundation
import SwiftData

@MainActor
extension MiraStore {
    func occupancyConvertedSnapshot(for item: CalendarItemSnapshot, occupiesTime: Bool) -> CalendarItemSnapshot? {
        guard let item = items.first(where: { $0.id == item.id }), item.kind == .confirmed else { return nil }
        var updated = item
        updated.occupiesTime = occupiesTime
        updated.bufferBeforeMinutes = 0
        updated.bufferAfterMinutes = 0
        updated.loadClass = .light
        updated.loadReason = ""
        if occupiesTime {
            let evaluation = loadEngine.evaluate(title: item.title, startDate: item.startDate,
                endDate: item.endDate, isAllDay: item.isAllDay, explicitRules: fetchLoadRules())
            updated.loadClass = evaluation.loadClass
            updated.loadReason = evaluation.reason
            updated.bufferBeforeMinutes = evaluation.bufferBeforeMinutes
            updated.bufferAfterMinutes = evaluation.bufferAfterMinutes
        } else {
            updated.isImportantTime = false
        }
        return updated
    }

    @discardableResult
    func setOccupiesTime(itemID: UUID, to value: Bool,
                        previewedSnapshot: CalendarItemSnapshot? = nil,
                        previewedMarginIDs: Set<UUID>? = nil) -> Bool {
        guard let current = items.first(where: { $0.id == itemID }), current.kind == .confirmed else { return false }
        let updated: CalendarItemSnapshot
        if let previewedSnapshot {
            var expected = current
            expected.occupiesTime = value
            expected.isImportantTime = value ? current.isImportantTime : false
            expected.loadClass = previewedSnapshot.loadClass
            expected.loadReason = previewedSnapshot.loadReason
            expected.bufferBeforeMinutes = previewedSnapshot.bufferBeforeMinutes
            expected.bufferAfterMinutes = previewedSnapshot.bufferAfterMinutes
            guard expected == previewedSnapshot else {
                toast = "予定が変更されました。もう一度影響を確認してください"
                return false
            }
            updated = previewedSnapshot
        } else {
            guard let converted = occupancyConvertedSnapshot(for: current, occupiesTime: value) else { return false }
            updated = converted
        }
        let impact = previewImpact(for: updated)
        if let previewedMarginIDs, previewedMarginIDs != Set(impact.overlappingMargins.map(\.id)) {
            toast = "余白が変更されました。もう一度影響を確認してください"
            return false
        }
        let undo = captureCalendarUndo(title: "予定の変更")
        do {
            guard let entity = try entity(id: itemID) else { return false }
            for margin in impact.overlappingMargins {
                if let occupied = try self.entity(id: margin.id) { context.delete(occupied) }
            }
            entity.apply(updated)
            try context.save()
            try refresh()
            finishCalendarMutation(undo)
            updateMarginRecommendation(for: updated.startDate)
            recalculateBalance(for: updated.startDate)
            return true
        } catch {
            context.rollback()
            toast = "余白の計算設定を保存できませんでした"
            return false
        }
    }
}
