import SwiftUI

struct MarginComfortSettingsView: View {
    @Environment(MiraStore.self) private var store
    let palette: MiraThemePalette

    @State private var selectedLevel: MarginComfortLevel = .standard

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MiraSpacing.lg) {
                HStack(spacing: MiraSpacing.md) {
                    PixelCatView(mood: .relaxed, size: 82)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("休む量もMiraに任せられるにゃ")
                            .font(.title3.bold())
                        Text("その月の予定負荷を見て、必要な余白目標を自動計算します。")
                            .font(.subheadline)
                            .foregroundStyle(palette.secondaryText)
                    }
                }

                ForEach(MarginComfortLevel.allCases) { level in
                    Button {
                        selectedLevel = level
                    } label: {
                        HStack(spacing: MiraSpacing.sm) {
                            Image(systemName: selectedLevel == level ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedLevel == level ? palette.accent : palette.secondaryText)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(level.title)
                                    .font(.headline)
                                Text(level.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(palette.secondaryText)
                            }
                            Spacer()
                        }
                        .foregroundStyle(palette.primaryText)
                        .miraCard(palette, padding: MiraSpacing.sm)
                    }
                    .buttonStyle(MiraPressStyle())
                }

                VStack(alignment: .leading, spacing: MiraSpacing.sm) {
                    Label("今月の再計算結果", systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(palette.accent)
                    ForEach(MarginKind.allCases.filter { recommendation.targets[$0] != nil }) { kind in
                        HStack {
                            Image(systemName: kind.symbolName)
                                .frame(width: 24)
                                .foregroundStyle(palette.accent)
                            Text(kind.title)
                                .font(.subheadline)
                            Spacer()
                            Text("\(recommendation.targets[kind, default: 0])回")
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                        }
                    }
                    Divider().overlay(palette.primaryText.opacity(0.08))
                    ForEach(recommendation.reasons, id: \.self) { reason in
                        Text("・\(reason)")
                            .font(.caption)
                            .foregroundStyle(palette.secondaryText)
                    }
                }
                .miraCard(palette)

                PrimaryButton(title: "この設定で目標を更新", symbol: "checkmark", palette: palette) {
                    store.setMarginComfortLevel(selectedLevel, applyRecommendation: true)
                }
            }
            .padding(MiraSpacing.md)
        }
        .miraScreenBackground(palette)
        .navigationTitle("余白のおまかせ")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedLevel = store.marginComfortLevel
        }
    }

    private var recommendation: MarginRecommendation {
        store.marginRecommendationEngine.recommend(
            month: store.selectedMonth,
            items: store.items,
            comfort: selectedLevel
        )
    }
}
