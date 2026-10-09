import SwiftUI

/// The friend view as a picture: a month where busy days read only
/// "予定あり", ready to drop into a chat so friends can pick a free day.
struct FriendShareCard: View {
    let month: Date
    let items: [CalendarItemSnapshot]
    let palette: MiraThemePalette
    let weekStartDay: WeekStartDay
    let referenceDate: Date

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
                privacyMode: true
            )
            .clipShape(RoundedRectangle(cornerRadius: MiraRadius.medium, style: .continuous))
            Text("「予定あり」の日以外なら空いてるよ")
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
