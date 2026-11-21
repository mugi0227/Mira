import SwiftUI

/// A recipient-specific card showing only content permitted by their share level.
struct FriendShareCard: View {
    let month: Date
    let items: [CalendarItemSnapshot]
    let palette: MiraThemePalette
    let weekStartDay: WeekStartDay
    let referenceDate: Date
    var baseRules: [BaseAvailabilityRule] = []
    var level: FriendShareLevel = .freeOnly
    var recipientName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: MiraSpacing.sm) {
            if level != .hidden {
                if let recipientName { Text("\(recipientName)さんへ").font(.headline) }
                HStack(alignment: .firstTextBaseline) {
                    Text(month.japaneseMonthTitle)
                        .font(.title2.bold())
                        .foregroundStyle(palette.primaryText)
                    Spacer()
                    Label(level == .freeOnly ? "空いている日はここ" : level.title, systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.accent)
                }
                MonthCalendarGrid(
                    month: month,
                    selectedDate: .constant(.distantPast),
                    items: items,
                    palette: palette,
                    weekStartDay: weekStartDay,
                    referenceDate: referenceDate,
                    allowsDragging: false,
                    privacyMode: true,
                    friendLevel: level,
                    baseRules: baseRules
                )
                .clipShape(RoundedRectangle(cornerRadius: MiraRadius.medium, style: .continuous))
                Text(level.explanation)
                    .font(.footnote)
                    .foregroundStyle(palette.secondaryText)
            }
        }
        .padding(MiraSpacing.md)
        .frame(width: 390)
        .background(palette.background)
    }
}

@MainActor
enum FriendShareRenderer {
    static func image(for card: FriendShareCard) -> Image? {
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        guard let uiImage = renderer.uiImage else { return nil }
        return Image(uiImage: uiImage)
    }
}
