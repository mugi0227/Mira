import SwiftUI

struct SettingsView: View {
    @Environment(MiraStore.self) private var store
    let palette: MiraThemePalette

    @State private var showResetConfirmation = false
    @State private var showImportantPeople = false
    @State private var showEverydayConfirmation = false

    var body: some View {
        List {
            if palette.isCatSkin {
                Section {
                    HStack(spacing: MiraSpacing.md) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Miraを、あなたらしく")
                                .font(.title3.bold())
                                .foregroundStyle(palette.primaryText)
                            Text("毎日に合う、心地よい使い方へ。")
                                .font(.subheadline)
                                .foregroundStyle(palette.secondaryText)
                        }
                        Spacer(minLength: 0)
                        MiraBotanicalAccent(palette: palette)
                            .frame(width: 48, height: 64)
                            .accessibilityHidden(true)
                    }
                    .padding(.vertical, MiraSpacing.xs)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                Toggle("日常の日時を使う", isOn: Binding(
                    get: { !store.demoModeEnabled },
                    set: { value in Task { await store.setDemoModeEnabled(!value) } }
                ))
                NavigationLink { DeviceCalendarSettingsView(palette: palette) } label: {
                    Label("iPhoneカレンダーと接続", systemImage: "calendar.badge.plus")
                }
                if store.demoModeEnabled {
                    Button("サンプルを片付けて日常用に始める") { showEverydayConfirmation = true }
                }
            } header: {
                Text("日常のカレンダー")
            } footer: {
                Text("日時を切り替えても、保存済みの予定はそのまま残ります。")
            }
            .listRowBackground(palette.surface)

            Section("着せ替え") {
                NavigationLink {
                    ThemePickerView(palette: palette)
                } label: {
                    SettingsRow(symbol: "paintpalette.fill", title: "スキン", value: store.theme.displayName, tint: palette.accent)
                }
                NavigationLink {
                    ColorLabelSettingsView(palette: palette)
                } label: {
                    SettingsRow(symbol: "swatchpalette.fill", title: "色のラベル", value: "\(store.colorLabels.count)色", tint: palette.accent)
                }
                Toggle("案内役を表示", systemImage: "bubble.left.and.bubble.right.fill", isOn: Binding(
                    get: { store.assistantEnabled },
                    set: { store.setAssistantEnabled($0) }
                ))
                Toggle("通知でもキャラ口調", systemImage: "bell.badge.fill", isOn: Binding(
                    get: { store.characterNotificationsEnabled },
                    set: { store.setCharacterNotificationsEnabled($0) }
                ))
            }
            .listRowBackground(palette.surface)

            Section {
                NavigationLink {
                    AccountSettingsView(palette: palette)
                } label: {
                    SettingsRow(
                        symbol: store.account?.premium == true ? "crown.fill" : "person.crop.circle",
                        title: "アカウント",
                        value: store.account == nil ? "未サインイン" : (store.account?.premium == true ? "プレミアム" : "サインイン中"),
                        tint: palette.accent
                    )
                }
            }
            .listRowBackground(palette.surface)

            Section {
                Picker("週の始まり", selection: Binding(
                    get: { store.weekStartDay },
                    set: { store.setWeekStartDay($0) }
                )) {
                    ForEach(WeekStartDay.allCases) { value in
                        Text(value.title).tag(value)
                    }
                }

                Toggle("iPhoneの祝日を表示", systemImage: "flag.fill", isOn: Binding(
                    get: { store.deviceHolidaysEnabled },
                    set: { enabled in Task { await store.setDeviceHolidaysEnabled(enabled) } }
                ))
            } header: {
                Text("カレンダー表示")
            } footer: {
                Text("祝日は、iPhoneで購読している「日本の祝日」カレンダーを使います。購読していない場合は表示されません。")
            }
            .listRowBackground(palette.surface)

            Section {
                NavigationLink {
                    MarginComfortSettingsView(palette: palette)
                } label: {
                    SettingsRow(
                        symbol: "sparkles.rectangle.stack.fill",
                        title: "余白のおまかせ",
                        value: store.marginComfortLevel.title,
                        tint: palette.success
                    )
                }
            } header: {
                Text("余白の設計")
            } footer: {
                Text("予定負荷を見て必要な休息量を自動計算します。少なめ・ふつう・多めから調整できます。")
            }
            .listRowBackground(palette.surface)

            Section {
                Toggle("返事や日程調整の期限を知らせる", systemImage: "bell.fill", isOn: Binding(
                    get: { store.notificationsEnabled },
                    set: { enabled in Task { await store.setNotificationsEnabled(enabled) } }
                ))
            } header: {
                Text("通知")
            } footer: {
                Text("同じ内容を何度も通知せず、返事期限など重要なものを優先します。")
            }
            .listRowBackground(palette.surface)

            Section("予定の理解") {
                NavigationLink { JevSettingsView(palette: palette) } label: {
                    Label("クラウドの入力補助", systemImage: "cloud")
                }
                NavigationLink {
                    AIStatusView(palette: palette)
                } label: {
                    SettingsRow(symbol: "brain.head.profile", title: "オンデバイスAI", value: store.aiStatus, tint: palette.accent)
                }
                NavigationLink {
                    LoadAndBufferSettingsView(palette: palette)
                } label: {
                    SettingsRow(symbol: "gauge.with.dots.needle.50percent", title: "負荷と前後の余白", value: "カテゴリ別", tint: palette.warning)
                }
            }
            .listRowBackground(palette.surface)

            Section("大切なもの") {
                Button { showImportantPeople = true } label: {
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

            Section {
                NavigationLink {
                    LegacyImportView(palette: palette)
                } label: {
                    SettingsRow(symbol: "arrow.down.doc.fill", title: "古いカレンダーから移行", value: "写真・PDF", tint: palette.success)
                }
            } header: {
                Text("カレンダーの引っ越し")
            } footer: {
                Text("カレンダー画面の写真やPDFから予定を読み取ります（Gemini使用）。iPhoneにある予定は「iPhoneカレンダーと接続」から読み込めます。")
            }
            .listRowBackground(palette.surface)

            Section("デモ") {
                Button(role: .destructive) { showResetConfirmation = true } label: {
                    Label("サンプル状態へリセット", systemImage: "arrow.counterclockwise")
                }
            }
            .listRowBackground(palette.surface)

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.demoModeEnabled ? "Mira・デモのカレンダー" : "Mira・あなたの余白").font(.caption.weight(.semibold))
                    Text("予定を埋める前に、自分が送りたい生活を守るカレンダー。")
                        .font(.caption2)
                        .foregroundStyle(palette.secondaryText)
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(palette.surface)
        }
        .scrollContentBackground(.hidden)
        .miraFormStyle(palette)
        .miraScreenBackground(palette)
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showImportantPeople) { ImportantPeopleSheet(palette: palette) }
        .confirmationDialog("Mira内のデータを片付けて始めますか？", isPresented: $showEverydayConfirmation) {
            Button("空のカレンダーで始める", role: .destructive) { Task { await store.startEverydayCalendar() } }
            Button("やめる", role: .cancel) {}
        } message: {
            Text("Mira内の予定・余白・調整・下書きを削除します。iPhoneカレンダーの予定は削除しません。")
        }
        .confirmationDialog("デモを最初の状態へ戻しますか？", isPresented: $showResetConfirmation) {
            Button("リセット", role: .destructive) { Task { await store.resetDemo() } }
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
            Image(systemName: symbol).foregroundStyle(tint).frame(width: 28).accessibilityHidden(true)
            Text(title)
            Spacer()
            Text(value).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
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
                    ThemePreviewCard(
                        theme: theme,
                        palette: MiraThemePalette(kind: theme, colorScheme: colorScheme),
                        selected: theme == store.theme
                    ) { withAnimation(MiraMotion.standard) { store.setTheme(theme) } }
                }
            }
            .padding(MiraSpacing.md)
        }
        .miraScreenBackground(palette)
        .navigationTitle("スキン")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ThemePreviewCard: View {
    let theme: AppThemeKind
    let palette: MiraThemePalette
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: MiraSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(theme.displayName).font(.title3.bold())
                        Text(theme == .pixelCat ? "空色とやわらかな光、猫と過ごす毎日" : "静かで大人っぽい、余白中心の見た目")
                            .font(.caption).foregroundStyle(palette.secondaryText)
                    }
                    Spacer()
                    if selected { Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(palette.accent) }
                }
                VStack(alignment: .leading, spacing: MiraSpacing.sm) {
                    HStack(spacing: MiraSpacing.sm) {
                        if theme == .pixelCat {
                            PixelCatView(mood: .relaxed, size: 64)
                        } else {
                            Image(systemName: "leaf.circle.fill").font(.system(size: 48)).foregroundStyle(palette.accent).frame(width: 64)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(theme == .pixelCat ? "いい感じだにゃ" : "今月はいいバランスです").font(.headline)
                            Text("予定も余白も、ちゃんと居場所があります。")
                                .font(.caption).foregroundStyle(palette.secondaryText)
                        }
                    }
                    if palette.isCatSkin {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 6) { previewChips }
                            VStack(alignment: .leading, spacing: 6) { previewChips }
                        }
                    }
                }
                .padding(MiraSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    if palette.isCatSkin {
                        RoundedRectangle(cornerRadius: MiraRadius.medium)
                            .fill(palette.backgroundGradient)
                    } else {
                        RoundedRectangle(cornerRadius: MiraRadius.small)
                            .fill(palette.elevatedSurface)
                    }
                }
            }
            .foregroundStyle(palette.primaryText)
            .miraCard(palette)
        }
        .buttonStyle(MiraPressStyle())
        .accessibilityLabel("\(theme.displayName)スキン" + (selected ? "、選択中" : ""))
    }

    private var previewChips: some View {
        Group {
            previewChip("休息", symbol: "moon.stars.fill", color: palette.rest)
            previewChip("読書", symbol: "book.closed.fill", color: palette.reading)
            previewChip("大切な時間", symbol: "heart.fill", color: palette.important)
        }
    }

    private func previewChip(_ title: String, symbol: String, color: Color) -> some View {
        Label(title, systemImage: symbol)
            .font(.caption.weight(.medium))
            .foregroundStyle(palette.primaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(color, in: Capsule())
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
                    Image(systemName: "brain.head.profile").font(.system(size: 68)).foregroundStyle(palette.accent)
                }
                VStack(spacing: MiraSpacing.xs) {
                    Text(store.aiStatus).font(.title2.bold()).foregroundStyle(palette.primaryText)
                    Text("対応端末では、Appleのオンデバイスモデルが雑な入力を構造化し、予定タイトルの負荷も分類します。")
                        .font(.body).foregroundStyle(palette.secondaryText).multilineTextAlignment(.center)
                }
                .miraCard(palette)
                VStack(alignment: .leading, spacing: MiraSpacing.sm) {
                    CapabilityRow(symbol: "checkmark.shield.fill", text: "予定を外部サーバーへ送らない", palette: palette)
                    CapabilityRow(symbol: "magnifyingglass", text: "案件検索はモデルより先に端末内で高速実行", palette: palette)
                    CapabilityRow(symbol: "function", text: "空き・余白・候補ランキングは決定論ロジック", palette: palette)
                    CapabilityRow(symbol: "arrow.triangle.2.circlepath", text: "非対応端末ではルールと定型文へ自動切替", palette: palette)
                    CapabilityRow(symbol: "eye.slash.fill", text: "行動履歴から勝手に性格を学習しない", palette: palette)
                }
                .miraCard(palette)
            }
            .padding(MiraSpacing.md)
        }
        .miraScreenBackground(palette)
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
            Image(systemName: symbol).foregroundStyle(palette.accent).frame(width: 28).accessibilityHidden(true)
            Text(text).font(.subheadline).foregroundStyle(palette.primaryText)
        }
        .frame(minHeight: 40)
    }
}

private struct LoadAndBufferSettingsView: View {
    let palette: MiraThemePalette
    private let rows = [
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
                    .font(.subheadline).foregroundStyle(palette.secondaryText)
            }
            .listRowBackground(palette.surface)
            Section("カテゴリの初期値") {
                ForEach(rows, id: \.0) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(row.0)
                            Spacer()
                            Text(row.1).font(.subheadline.weight(.semibold))
                                .foregroundStyle(row.1.contains("重") ? palette.warning : palette.accent)
                        }
                        Text(row.2).font(.caption).foregroundStyle(palette.secondaryText)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listRowBackground(palette.surface)
            Section {
                Text("予定詳細から負荷を訂正できます。同じ予定にも適用するかは毎回あなたが選びます。")
                    .font(.caption).foregroundStyle(palette.secondaryText)
            }
            .listRowBackground(palette.surface)
        }
        .scrollContentBackground(.hidden)
        .miraFormStyle(palette)
        .miraScreenBackground(palette)
        .navigationTitle("負荷と前後の余白")
        .navigationBarTitleDisplayMode(.inline)
    }
}
