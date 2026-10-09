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
        if let similar = colored.first(where: {
            $0.title.count >= 2 && ($0.title.contains(title) || title.contains($0.title))
        })?.colorTag {
            return similar
        }
        return colorProfile.suggestedColor(forTitle: title)
    }

    // MARK: - Labels and profile

    private static let labelsKey = "mira.colorLabels"
    private static let profileKey = "mira.colorProfile"

    /// The person's name for a color, if they gave it one.
    func label(for tag: EventColorTag) -> String? {
        colorLabels[tag].flatMap { $0.isEmpty ? nil : $0 }
    }

    func displayName(for tag: EventColorTag) -> String {
        label(for: tag) ?? tag.title
    }

    func setLabel(_ raw: String, for tag: EventColorTag) {
        let value = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(12))
        if value.isEmpty { colorLabels[tag] = nil } else { colorLabels[tag] = value }
        persistColorPreferences()
    }

    /// Turning a profile on fills in its labels where the person has none.
    func setColorProfile(_ profile: ColorProfile) {
        colorProfile = profile
        for (tag, label) in profile.defaultLabels where self.label(for: tag) == nil {
            colorLabels[tag] = label
        }
        persistColorPreferences()
    }

    func loadColorPreferences() {
        let defaults = UserDefaults.standard
        if let raw = defaults.dictionary(forKey: Self.labelsKey) as? [String: String] {
            colorLabels = Dictionary(uniqueKeysWithValues: raw.compactMap { key, value in
                EventColorTag(rawValue: key).map { ($0, value) }
            })
        }
        colorProfile = defaults.string(forKey: Self.profileKey).flatMap(ColorProfile.init(rawValue:)) ?? .standard
    }

    func resetColorPreferences() {
        colorLabels = [:]
        colorProfile = .standard
        UserDefaults.standard.removeObject(forKey: Self.labelsKey)
        UserDefaults.standard.removeObject(forKey: Self.profileKey)
    }

    private func persistColorPreferences() {
        let raw = Dictionary(uniqueKeysWithValues: colorLabels.map { ($0.key.rawValue, $0.value) })
        UserDefaults.standard.set(raw, forKey: Self.labelsKey)
        UserDefaults.standard.set(colorProfile.rawValue, forKey: Self.profileKey)
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
