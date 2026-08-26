import SwiftUI

struct SettingsView: View {
    @Environment(MiraStore.self) private var store
    let palette: MiraThemePalette

    @State private var showResetConfirmation = false
    @State private var showImportantPeople = false

    var body: some View {
        List {
            Section("着せ替え") {
                NavigationLink {
                    ThemePickerView(palette: palette)
                } label: {
                    SettingsRow(
                        symbol: "paintpalette.fill",
                        title: "スキン",
                        value: store.theme.displayName,
                        tint: palette.accent
                    )
                }

                Toggle(isOn: Binding(
                    get: { store.assistantEnabled },
                    set: { store.setAssistantEnabled($0) }
                )) {
                    Label("案内役を表示", systemImage: "bubble.left.and.bubble.right.fill")
                }

                Toggle(isOn: Binding(
                    get: { store.characterNotificationsEnabled },
                    set: { store.setCharacterNotificationsEnabled($0) }
                )) {
                    Label("通知でもキャラ口調", systemImage: "bell.badge.fill")
                }
            }
            .listRowBackground(palette.surface)

            Section("通知") {
                Toggle(isOn: Binding(
                    get: { store.notificationsEnabled },
                    set: { enabled in Task { await store.setNotificationsEnabled(enabled) } }
                )) {
                    Label("調整期限・余白不足を知らせる", systemImage: "bell.fill")
                }
            } footer: {
                Text("同じ内容を何度も通知せず、返事期限など重要なものを優先します。")
            }
            .listRowBackground(palette.surface)

            Section("予定の理解") {
                NavigationLink {
                    AIStatusView(palette: palette)
                } label: {
                    SettingsRow(
                        symbol: "apple.intelligence",
                        title: "オンデバイスAI",
                        value: store.aiStatus,
                        tint: palette.accent
                    )
                }

                NavigationLink {
                    LoadAndBufferSettingsView(palette: palette)
                } label: {
                    SettingsRow(
                        symbol: "gauge.with.dots.needle.67percent",
                        title: "負荷と前後の余白",
                        value: "カテゴリ別",
                        tint: palette.warning
                    )
                }
            }
            .listRowBackground(palette.surface)

            Section("大切なもの") {
                Button {
                    showImportantPeople = true
                } label: {
                    SettingsRow(
                        symbol: "heart.fill",
                        title: "大切な人",
                        value: store.importantPeople.isEmpty ? "未登録" : "\(store.importantPeople.count)人",
                        tint: palette.important
                    )
                }
                .buttonStyle(.plain)
            }
            .listRowBackground(palette.surface)

            Section("カレンダーの引っ越し") {
                NavigationLink {
                    LegacyImportView(palette: palette)
                } label: {
                    SettingsRow(
                        symbol: "arrow.down.doc.fill",
                        title: "古いカレンダーから移行",
                        value: "PDF・画像",
                        tint: palette.success
                    )
                }
            } footer: {
                Text("デモでは抽出画面まで動作します。実際のOCRとEventKit登録は本番フェーズで接続します。")
            }
            .listRowBackground(palette.surface)

            Section("デモ") {
                Button(role: .destructive) {
                    showResetConfirmation = true
                } label: {
                    Label("サンプル状態へリセット", systemImage: "arrow.counterclockwise")
                }
            }
            .listRowBackground(palette.surface)

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("余白 Calendar Demo")
                        .font(.caption.weight(.semibold))
                    Text("予定を埋める前に、自分が送りたい生活を守るカレンダー。")
                        .font(.caption2)
                        .foregroundStyle(palette.secondaryText)
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(palette.surface)
        }
        .scrollContentBackground(.hidden)
        .background(palette.background)
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showImportantPeople) {
            ImportantPeopleSheet(palette: palette)
        }
        .confirmationDialog("デモを最初の状態へ戻しますか？", isPresented: $showResetConfirmation) {
            Button("リセット", role: .destructive) {
                Task { await store.resetDemo() }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("追加した予定や設定も削除されます。")
        }
        .tint(palette.accent)
    }
}

private struct SettingsRow: View {
    let symbol: String
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: MiraSpacing.sm) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .frame(width: 28)
                .accessibilityHidden(true)
            Text(title)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}

private struct ThemePickerView: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    let palette: MiraThemePalette

    var body: some View {
        ScrollView {
            VStack(spacing: MiraSpacing.lg) {
                ForEach(AppThemeKind.allCases) { theme in
                    let previewPalette = MiraThemePalette(kind: theme, colorScheme: colorScheme)
                    Button {
                        withAnimation(MiraMotion.standard) { store.setTheme(theme) }
                    } label: {
                        VStack(alignment: .leading, spacing: MiraSpacing.md) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(theme.displayName)
                                        .font(.title3.bold())
                                    Text(theme == .pixelCat ? "小さなドット猫と、やさしい猫口調" : "静かで大人っぽい、余白中心の見た目")
                                        .font(.caption)
                                        .foregroundStyle(previewPalette.secondaryText)
                                }
                                Spacer()
                                if theme == store.theme {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(previewPalette.accent)
                                }
                            }
                            HStack(spacing: MiraSpacing.sm) {
                                if theme == .pixelCat {
                                    PixelCatView(mood: .relaxed, size: 64)
                                } else {
                                    Image(systemName: "leaf.circle.fill")
                                        .font(.system(size: 48))
                                        .foregroundStyle(previewPalette.accent)
                                        .frame(width: 64)
                                }
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(theme == .pixelCat ? "いい感じだにゃ" : "今月はいいバランスです")
                                        .font(.headline)
                                    Text("予定も余白も、ちゃんと居場所があります。")
                                        .font(.caption)
                                        .foregroundStyle(previewPalette.secondaryText)
                                }
                            }
                            .padding(MiraSpacing.sm)
                            .background(previewPalette.elevatedSurface, in: RoundedRectangle(cornerRadius: MiraRadius.small))
                        }
                        .foregroundStyle(previewPalette.primaryText)
                        .miraCard(previewPalette)
                    }
                    .buttonStyle(MiraPressStyle())
                    .accessibilityLabel("\(theme.displayName)スキン" + (theme == store.theme ? "、選択中" : ""))
                }
            }
            .padding(MiraSpacing.md)
        }
        .background(palette.background)
        .navigationTitle("スキン")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AIStatusView: View {
    @Environment(MiraStore.self) private var store
    let palette: MiraThemePalette

    var body: some View {
        ScrollView {
            VStack(spacing: MiraSpacing.lg) {
                if store.theme == .pixelCat {
                    PixelCatView(mood: .thinking, size: 108)
                } else {
                    Image(systemName: "apple.intelligence")
                        .font(.system(size: 68))
                        .foregroundStyle(palette.accent)
                }

                VStack(spacing: MiraSpacing.xs) {
                    Text(store.aiStatus)
                        .font(.title2.bold())
                        .foregroundStyle(palette.primaryText)
                    Text("対応端末では、Appleのオンデバイスモデルが予定タイトルを分類し、猫の言葉を自然にします。")
                        .font(.body)
                        .foregroundStyle(palette.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .miraCard(palette)

                VStack(alignment: .leading, spacing: MiraSpacing.sm) {
                    CapabilityRow(symbol: "checkmark.shield.fill", text: "予定を外部サーバーへ送らない", palette: palette)
                    CapabilityRow(symbol: "function", text: "日程の可否は決定論的ロジックが判断", palette: palette)
                    CapabilityRow(symbol: "arrow.trianglehead.2.clockwise", text: "非対応端末ではルールと定型文へ自動切替", palette: palette)
                    CapabilityRow(symbol: "eye.slash.fill", text: "行動履歴から勝手に学習しない", palette: palette)
                }
                .miraCard(palette)
            }
            .padding(MiraSpacing.md)
        }
        .background(palette.background)
        .navigationTitle("オンデバイスAI")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CapabilityRow: View {
    let symbol: String
    let text: String
    let palette: MiraThemePalette

    var body: some View {
        HStack(spacing: MiraSpacing.sm) {
            Image(systemName: symbol)
                .foregroundStyle(palette.accent)
                .frame(width: 28)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(palette.primaryText)
        }
        .frame(minHeight: 40)
    }
}

private struct LoadAndBufferSettingsView: View {
    let palette: MiraThemePalette

    private let rows: [(String, String, String)] = [
        ("美容院", "ふつう", "前30分・後45分"),
        ("映画", "ふつう", "前45分・後45分"),
        ("外食", "ふつう", "前45分・後60分"),
        ("飲み会", "重め", "前45分・後120分"),
        ("旅行・登山", "かなり重い", "実質終日")
    ]

    var body: some View {
        List {
            Section {
                Text("予定に書かれた時間だけでなく、準備・移動・帰宅後の回復まで生活占有時間として扱います。")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
            }
            .listRowBackground(palette.surface)

            Section("カテゴリの初期値") {
                ForEach(rows, id: \.0) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(row.0)
                            Spacer()
                            Text(row.1)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(row.1.contains("重") ? palette.warning : palette.accent)
                        }
                        Text(row.2)
                            .font(.caption)
                            .foregroundStyle(palette.secondaryText)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listRowBackground(palette.surface)

            Section {
                Text("予定詳細から『軽め／ふつう／重め』を訂正できます。同じ予定にも適用するかは毎回あなたが選びます。")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            }
            .listRowBackground(palette.surface)
        }
        .scrollContentBackground(.hidden)
        .background(palette.background)
        .navigationTitle("負荷と前後の余白")
        .navigationBarTitleDisplayMode(.inline)
    }
}
