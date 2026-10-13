import SwiftUI

/// Shares morning, afternoon and evening availability without event titles.
struct FriendShareCard: View {
    let month: Date
    let items: [CalendarItemSnapshot]
    let palette: MiraThemePalette
    let weekStartDay: WeekStartDay
    let referenceDate: Date
    var baseRules: [BaseAvailabilityRule] = []

    var body: some View {
        VStack(alignment: .leading, spacing: MiraSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(month.japaneseMonthTitle)
                    .font(.title2.bold())
                    .foregroundStyle(palette.primaryText)
                Spacer()
                Label("空いている日はここ", systemImage: "sparkles")
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
                baseRules: baseRules
            )
            .clipShape(RoundedRectangle(cornerRadius: MiraRadius.medium, style: .continuous))
            Text("朝 8–12時・昼 12–18時・夜 18–24時\n「予定」はその時間帯に予定や仕事が入っています。")
                .font(.footnote)
                .foregroundStyle(palette.secondaryText)
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
