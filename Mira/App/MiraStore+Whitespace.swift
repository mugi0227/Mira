import Foundation
import SwiftData

@MainActor
extension MiraStore {
    func setOccupiesTime(itemID: UUID, to value: Bool) {
        do {
            guard let entity = try context.fetch(FetchDescriptor<CalendarItemEntity>())
                .first(where: { $0.id == itemID }) else { return }
            entity.occupiesTime = value
            entity.updatedAt = .now
            try context.save()
            try refresh()
        } catch {
            toast = "余白の計算設定を保存できませんでした"
        }
    }
}
