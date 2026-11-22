import SwiftUI

struct WorkDayToggle: View {
    @Environment(MiraStore.self) private var store
    let date: Date
    let palette: MiraThemePalette
    @State private var showsExplanation = false
    @State private var explanationHeight: CGFloat = 280

    static func symbol(isWorkDay: Bool) -> String {
        isWorkDay ? "briefcase.fill" : "briefcase"
    }

    var body: some View {
        HStack(spacing: MiraSpacing.sm) {
            Button { showsExplanation = true } label: {
                Image(systemName: Self.symbol(isWorkDay: store.isWorkDay(date)))
                    .font(.title3)
                    .foregroundStyle(palette.secondaryText)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("仕事の日について")
            .accessibilityIdentifier("workDayInfoButton")

            Button {
                store.setWorkDay(date, !store.isWorkDay(date))
            } label: {
                HStack(spacing: MiraSpacing.sm) {
                    Text("仕事の日")
                    Image(systemName: store.isWorkDay(date) ? "checkmark.circle.fill" : "circle")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(store.isWorkDay(date) ? palette.accent : palette.secondaryText)
                .padding(.horizontal, MiraSpacing.md)
                .frame(minHeight: 44)
                .background(store.isWorkDay(date) ? palette.accentSoft : palette.surface, in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("仕事の日")
            .accessibilityValue(store.isWorkDay(date) ? "オン" : "オフ")
            .accessibilityIdentifier("workDayToggle")
        }
        .foregroundStyle(palette.primaryText)
        .sheet(isPresented: $showsExplanation) {
            NavigationStack {
                VStack(alignment: .leading, spacing: MiraSpacing.lg) {
                    Label("仕事の日について", systemImage: Self.symbol(isWorkDay: store.isWorkDay(date)))
                        .font(.title2.bold())
                    Text(explanation)
                        .font(.body)
                        .lineSpacing(5)
                        .accessibilityIdentifier("workDayExplanation")
                }
                .foregroundStyle(palette.primaryText)
                .padding(MiraSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    explanationHeight = height + 56
                }
                .miraScreenBackground(palette)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("閉じる") { showsExplanation = false }
                    }
                }
            }
            .presentationDetents([.height(explanationHeight)])
        }
    }

    private var explanation: String {
        var workDays = store.workDayResolver
        workDays.overrides[Calendar.mira.startOfDay(for: date)] = true
        let intervals = workDays.intervals(on: date, rules: store.fetchBaseRules())
        let hours = intervals.map {
            "\(DateFormatter.mira("H:mm").string(from: $0.start))–\(DateFormatter.mira("H:mm").string(from: $0.end))"
        }.joined(separator: "、")
        let basicHours = hours.isEmpty ? "基本時間（設定で追加できます）" : "基本時間（\(hours)）"
        return "仕事の日は\(basicHours)を仕事として扱い、余白や候補日から外します。この日だけ切り替えられます。祝日の扱いは設定で変更できます。"
    }
}
