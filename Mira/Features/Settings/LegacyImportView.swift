import SwiftUI

struct LegacyImportView: View {
    @Environment(MiraStore.self) private var store
    let palette: MiraThemePalette

    @State private var step: ImportStep = .intro
    @State private var source: LegacySource = .yahoo
    @State private var selectedIDs: Set<UUID> = []
    @State private var progress = 0.0

    private let items = LegacyImportSample.items

    var body: some View {
        content
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .miraScreenBackground(palette)
        .navigationTitle("カレンダーの引っ越し")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: step) { _, newValue in
            if newValue == .review, selectedIDs.isEmpty {
                selectedIDs = Set(items.map(\.id))
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .intro: intro
        case .source: sourceSelection
        case .analyzing: analyzing
        case .review: review
        case .duplicates: duplicates
        case .completed: completed
        }
    }

    private var intro: some View {
        ScrollView {
            VStack(spacing: MiraSpacing.xl) {
                Spacer(minLength: MiraSpacing.lg)
                if store.theme == .pixelCat {
                    PixelCatView(mood: .happy, size: 132)
                } else {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 76))
                        .foregroundStyle(palette.accent)
                }
                VStack(spacing: MiraSpacing.sm) {
                    Text("大切な予定だけ、連れてこよう")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                        .foregroundStyle(palette.primaryText)
                    Text("古いカレンダーのPDFやスクリーンショットから、将来予定・誕生日・繰り返し予定をまとめて確認できます。")
                        .font(.body)
                        .foregroundStyle(palette.secondaryText)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: MiraSpacing.sm) {
                    ImportFeatureRow(symbol: "calendar.badge.clock", text: "これから先の予定", palette: palette)
                    ImportFeatureRow(symbol: "gift.fill", text: "毎年の誕生日・記念日", palette: palette)
                    ImportFeatureRow(symbol: "repeat", text: "毎週・毎月の繰り返し", palette: palette)
                    ImportFeatureRow(symbol: "checkmark.shield.fill", text: "取り込む前に、必ず自分で確認", palette: palette)
                }
                .miraCard(palette)

                PrimaryButton(title: "移行を試す", symbol: "arrow.right", palette: palette) {
                    withAnimation(MiraMotion.standard) { step = .source }
                }
            }
            .padding(MiraSpacing.md)
            .padding(.bottom, MiraSpacing.xl)
        }
    }

    private var sourceSelection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MiraSpacing.lg) {
                Text("どのカレンダーから移しますか？")
                    .font(.title2.bold())
                    .foregroundStyle(palette.primaryText)

                ForEach(LegacySource.allCases) { candidate in
                    Button {
                        source = candidate
                    } label: {
                        HStack(spacing: MiraSpacing.md) {
                            Image(systemName: candidate.symbol)
                                .font(.title2)
                                .foregroundStyle(palette.accent)
                                .frame(width: 48, height: 48)
                                .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: MiraRadius.small))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(candidate.title)
                                    .font(.headline)
                                Text(candidate.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(palette.secondaryText)
                            }
                            Spacer()
                            Image(systemName: source == candidate ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(source == candidate ? palette.accent : palette.secondaryText)
                        }
                        .foregroundStyle(palette.primaryText)
                        .miraCard(palette, padding: MiraSpacing.sm)
                    }
                    .buttonStyle(MiraPressStyle())
                }

                VStack(alignment: .leading, spacing: MiraSpacing.sm) {
                    Label("デモ用のサンプルPDFを使います", systemImage: "doc.fill")
                        .font(.headline)
                    Text("本番版では、PDFまたはスクリーンショットを選び、端末内で読み取ります。")
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                }
                .miraCard(palette)

                PrimaryButton(title: "サンプルPDFを読み取る", symbol: "doc.text.magnifyingglass", palette: palette) {
                    beginAnalysis()
                }
            }
            .padding(MiraSpacing.md)
            .padding(.bottom, MiraSpacing.xl)
        }
    }

    private var analyzing: some View {
        VStack(spacing: MiraSpacing.xl) {
            if store.theme == .pixelCat {
                PixelCatView(mood: .thinking, size: 124)
            }
            ProgressView(value: progress)
                .tint(palette.accent)
                .frame(maxWidth: 260)
            VStack(spacing: MiraSpacing.xs) {
                Text("予定を読み取っています")
                    .font(.title2.bold())
                    .foregroundStyle(palette.primaryText)
                Text(analysisLabel)
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
            }
        }
        .padding(MiraSpacing.xl)
        .task {
            guard progress == 0 else { return }
            for value in 1...10 {
                try? await Task.sleep(for: .milliseconds(160))
                withAnimation(.linear(duration: 0.14)) { progress = Double(value) / 10 }
            }
            try? await Task.sleep(for: .milliseconds(220))
            withAnimation(MiraMotion.standard) { step = .review }
        }
    }

    private var review: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MiraSpacing.lg) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("読み取った予定")
                        .font(.title2.bold())
                        .foregroundStyle(palette.primaryText)
                    Text("\(selectedIDs.count)件を選択中。誕生日は毎年の予定として取り込みます。")
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                }

                ForEach(LegacyImportCategory.allCases) { category in
                    let categoryItems = items.filter { $0.category == category }
                    VStack(alignment: .leading, spacing: MiraSpacing.sm) {
                        Label(category.title, systemImage: category.symbol)
                            .font(.headline)
                            .foregroundStyle(palette.primaryText)
                        ForEach(categoryItems) { item in
                            Button {
                                if selectedIDs.contains(item.id) {
                                    selectedIDs.remove(item.id)
                                } else {
                                    selectedIDs.insert(item.id)
                                }
                            } label: {
                                HStack(spacing: MiraSpacing.sm) {
                                    Image(systemName: selectedIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedIDs.contains(item.id) ? palette.accent : palette.secondaryText)
                                        .font(.title3)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.title)
                                            .font(.subheadline.weight(.semibold))
                                        Text(item.detail)
                                            .font(.caption)
                                            .foregroundStyle(palette.secondaryText)
                                    }
                                    Spacer()
                                }
                                .foregroundStyle(palette.primaryText)
                                .frame(minHeight: 48)
                            }
                            .buttonStyle(MiraPressStyle())
                        }
                    }
                    .miraCard(palette)
                }

                PrimaryButton(title: "重複を確認", symbol: "rectangle.on.rectangle", palette: palette, isDisabled: selectedIDs.isEmpty) {
                    withAnimation(MiraMotion.standard) { step = .duplicates }
                }
            }
            .padding(MiraSpacing.md)
            .padding(.bottom, MiraSpacing.xl)
        }
    }

    private var duplicates: some View {
        ScrollView {
            VStack(spacing: MiraSpacing.lg) {
                if store.theme == .pixelCat {
                    PixelCatView(mood: .thinking, size: 96)
                }
                VStack(spacing: MiraSpacing.xs) {
                    Text("重複候補が1件あります")
                        .font(.title2.bold())
                        .foregroundStyle(palette.primaryText)
                    Text("同じ予定を二重に作らないよう、既存予定と照合します。")
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: MiraSpacing.sm) {
                    Label("11月21日 ライブ", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(palette.warning)
                    Text("すでに同じ日・同じタイトルの予定があります。この1件は取り込み対象から外します。")
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                    Label("既存予定を残す", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.success)
                }
                .miraCard(palette)

                PrimaryButton(title: "\(max(0, selectedIDs.count - 1))件を取り込む", symbol: "square.and.arrow.down", palette: palette) {
                    withAnimation(MiraMotion.standard) { step = .completed }
                }
            }
            .padding(MiraSpacing.md)
        }
    }

    private var completed: some View {
        VStack(spacing: MiraSpacing.xl) {
            if store.theme == .pixelCat {
                PixelCatView(mood: .celebrating, size: 132)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(palette.success)
            }
            VStack(spacing: MiraSpacing.sm) {
                Text("引っ越しの準備ができました")
                    .font(.title2.bold())
                    .foregroundStyle(palette.primaryText)
                Text("将来予定、誕生日、繰り返し予定を確認できました。実際の登録はEventKit接続後に行います。")
                    .font(.body)
                    .foregroundStyle(palette.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .miraCard(palette)
            Button("もう一度デモを見る") {
                progress = 0
                selectedIDs = []
                step = .intro
            }
            .buttonStyle(.bordered)
            .tint(palette.accent)
            .frame(minHeight: 44)
        }
        .padding(MiraSpacing.md)
    }

    private var analysisLabel: String {
        switch progress {
        case ..<0.35: "日付とタイトルを確認中"
        case ..<0.7: "繰り返しパターンを確認中"
        default: "誕生日と重複候補を整理中"
        }
    }

    private func beginAnalysis() {
        progress = 0
        withAnimation(MiraMotion.standard) { step = .analyzing }
    }
}
