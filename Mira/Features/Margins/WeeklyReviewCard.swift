import SwiftUI

/// "Did this week feel like mine?" Own time against the week's share of the
/// monthly goals, how suggestions went, and a one-tap feeling.
struct WeeklyReviewCard: View {
    @Environment(MiraStore.self) private var store
    let palette: MiraThemePalette

    var body: some View {
        let week = store.currentWeek
        let summary = store.weeklyReview(for: week)
        VStack(alignment: .leading, spacing: MiraSpacing.sm) {
            HStack {
                Text("今週のふりかえり")
                    .font(.title3.bold())
                    .foregroundStyle(palette.primaryText)
                Spacer()
                Text(rangeLabel(week))
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(summary.selfTimeHours.rounded()))")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(palette.primaryText)
                Text("時間の自分の時間")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primaryText)
                Spacer()
                Text("目安 \(Int(summary.targetHours))時間")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("weeklyReviewHours")

            ProgressView(value: summary.ratio)
                .tint(summary.ratio >= 1 ? palette.success : palette.accent)

            HStack(spacing: MiraSpacing.xs) {
                metricChip("置いた提案 \(summary.appliedSuggestions)", symbol: "leaf.fill")
                metricChip("見送り \(summary.dismissedSuggestions)", symbol: "xmark")
            }

            Text("今週はどうだった？")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.primaryText)
                .padding(.top, MiraSpacing.xxs)
            HStack(spacing: MiraSpacing.xs) {
                ForEach(Satisfaction.allCases) { value in
                    satisfactionButton(value, selected: summary.satisfaction == value, week: week)
                }
            }
            if summary.satisfaction == .low {
                Text("来週は自分の時間を少し多めに提案するね。")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            }
        }
        .miraCard(palette)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("weeklyReviewCard")
    }

    private func metricChip(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(palette.secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(palette.accentSoft.opacity(0.6), in: Capsule())
    }

    private func satisfactionButton(_ value: Satisfaction, selected: Bool, week: WeekKey) -> some View {
        Button {
            withAnimation(MiraMotion.quick) { store.setSatisfaction(value, for: week) }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: value.symbolName)
                    .font(.title3)
                    .accessibilityHidden(true)
                Text(value.title)
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .foregroundStyle(selected ? palette.onAccent : palette.primaryText)
            .background(selected ? palette.accent : palette.accentSoft.opacity(0.6),
                        in: RoundedRectangle(cornerRadius: MiraRadius.small, style: .continuous))
        }
        .buttonStyle(MiraPressStyle())
        .accessibilityLabel(value.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("satisfaction-\(value.rawValue)")
    }

    private func rangeLabel(_ week: WeekKey) -> String {
        let formatter = DateFormatter.mira("M/d")
        return "\(formatter.string(from: week.start))–\(formatter.string(from: week.start.addingDays(6)))"
    }
}
