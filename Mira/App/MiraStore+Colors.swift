import Foundation

@MainActor
extension MiraStore {
    /// Reuses the color of the most recent plan with a similar title, so
    /// "〇〇とご飯" keeps its color without asking every time.
    func suggestedColor(forTitle rawTitle: String) -> EventColorTag? {
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.count >= 2 else { return nil }
        let colored = items
            .filter { $0.kind != .margin && $0.colorTag != nil }
            .sorted { $0.startDate > $1.startDate }
        if let exact = colored.first(where: { $0.title == title }) {
            return exact.colorTag
        }
        return colored.first {
            $0.title.count >= 2 && ($0.title.contains(title) || title.contains($0.title))
        }?.colorTag
    }

    func setColor(itemID: UUID, to tag: EventColorTag?) {
        do {
            guard let entity = try entity(id: itemID) else { return }
            guard entity.colorTagRaw != tag?.rawValue else { return }
            let undo = captureCalendarUndo(title: "色の変更")
            entity.colorTagRaw = tag?.rawValue
            entity.updatedAt = .now
            try context.save()
            try refresh()
            finishCalendarMutation(undo)
        } catch {
            context.rollback()
            toast = "色を変更できませんでした"
        }
    }
}
