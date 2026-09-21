import SwiftUI

struct EventDetailSheet: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let item: CalendarItemSnapshot
    let palette: MiraThemePalette

    @State private var selectedLoad: LoadClass
    @State private var rememberSimilar = false
    @State private var showDeleteConfirmation = false

    init(item: CalendarItemSnapshot, palette: MiraThemePalette) {
        self.item = item
        self.palette = palette
        _selectedLoad = State(initialValue: item.loadClass)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MiraSpacing.lg) {
                    header
                    detailCard
                    DeviceCalendarActionView(item: item, palette: palette)
                    if item.kind != .margin && item.kind != .birthday {
                        loadCard
                    }
                    if item.kind == .margin {
                        marginCard
                    }
                    if item.deviceEvent == nil { deleteButton }
                }
                .padding(MiraSpacing.md)
                .padding(.bottom, MiraSpacing.xl)
            }
            .miraScreenBackground(palette)
            .navigationTitle("詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .confirmationDialog("この項目を削除しますか？", isPresented: $showDeleteConfirmation) {
                Button("削除", role: .destructive) {
                    store.deleteItem(id: item.id)
                    dismiss()
                }
                Button("キャンセル", role: .cancel) {}
            }
        }
        .tint(palette.accent)
    }

    private var header: some View {
        VStack(spacing: MiraSpacing.sm) {
            ZStack {
                Circle()
                    .fill(palette.color(for: item))
                    .frame(width: 76, height: 76)
                Image(systemName: symbol)
                    .font(.system(size: 31, weight: .semibold))
                    .foregroundStyle(palette.primaryText)
            }
            Text(item.title)
                .font(.title2.bold())
                .foregroundStyle(palette.primaryText)
                .multilineTextAlignment(.center)
            if item.isImportantTime {
                Label("大切な人との時間", systemImage: "heart.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.accent)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var detailCard: some View {
        VStack(spacing: MiraSpacing.sm) {
            DetailRow(symbol: "calendar", title: "日付", value: item.startDate.japaneseDayTitle, palette: palette)
            Divider().overlay(palette.primaryText.opacity(0.08))
            DetailRow(
                symbol: item.exactTimeKnown ? "clock" : "clock.badge.questionmark",
                title: "時間",
                value: item.timeDescription,
                palette: palette
            )
            if !item.exactTimeKnown {
                Divider().overlay(palette.primaryText.opacity(0.08))
                HStack(alignment: .top, spacing: MiraSpacing.sm) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(palette.accent)
                        .frame(width: 28)
                    Text("日付と時間帯は確定済みです。正確な集合時刻は、決まった後から雑入力でも追記できます。")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                }
            }
            if item.bufferBeforeMinutes > 0 && !item.isAllDay {
                DetailRow(symbol: "figure.walk", title: "準備を始める目安",
                    value: item.startDate.addingTimeInterval(-Double(item.bufferBeforeMinutes) * 60)
                        .formatted(date: .omitted, time: .shortened), palette: palette)
            }
            if item.bufferBeforeMinutes > 0 || item.bufferAfterMinutes > 0 {
                Divider().overlay(palette.primaryText.opacity(0.08))
                DetailRow(
                    symbol: "arrow.left.and.right",
                    title: "前後の余白",
                    value: "前 \(item.bufferBeforeMinutes)分・後 \(item.bufferAfterMinutes)分",
                    palette: palette
                )
            }
        }
        .miraCard(palette)
    }

    private var loadCard: some View {
        VStack(alignment: .leading, spacing: MiraSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("この予定の負荷")
                        .font(.headline)
                        .foregroundStyle(palette.primaryText)
                    Text(item.loadReason)
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                }
                Spacer()
                Text(selectedLoad.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(selectedLoad >= .heavy ? palette.warning : palette.accent)
            }

            Picker("負荷", selection: $selectedLoad) {
                ForEach([LoadClass.light, .normal, .heavy], id: \.self) { load in
                    Text(load.title).tag(load)
                }
            }
            .pickerStyle(.segmented)

            Toggle("同じ予定名にも覚えておく", isOn: $rememberSimilar)
                .font(.subheadline)

            PrimaryButton(
                title: "負荷を更新",
                symbol: "checkmark",
                palette: palette,
                isDisabled: selectedLoad == item.loadClass && !rememberSimilar
            ) {
                store.correctLoad(itemID: item.id, to: selectedLoad, rememberKeyword: rememberSimilar)
                dismiss()
            }
        }
        .miraCard(palette)
    }

    private var marginCard: some View {
        VStack(alignment: .leading, spacing: MiraSpacing.xs) {
            Label("守っている余白", systemImage: "shield.lefthalf.filled")
                .font(.headline)
                .foregroundStyle(palette.accent)
            Text("新しい予定と重なるときは、消す前に別の日への移動候補を出します。")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
        }
        .miraCard(palette)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Label("削除", systemImage: "trash")
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.bordered)
        .tint(palette.critical)
    }

    private var symbol: String {
        if item.kind == .margin { return item.marginKind?.symbolName ?? "leaf.fill" }
        if item.kind == .birthday { return "gift.fill" }
        if item.isImportantTime { return "heart.fill" }
        return item.exactTimeKnown ? "calendar" : "clock.badge.questionmark"
    }
}

private struct DetailRow: View {
    let symbol: String
    let title: String
    let value: String
    let palette: MiraThemePalette

    var body: some View {
        HStack(spacing: MiraSpacing.sm) {
            Image(systemName: symbol)
                .foregroundStyle(palette.accent)
                .frame(width: 28)
                .accessibilityHidden(true)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.primaryText)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}
