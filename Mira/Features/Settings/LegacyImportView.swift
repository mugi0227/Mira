import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Moves plans out of another calendar by reading screenshots or photos of
/// it (PC Yahoo!カレンダー works best: titles are never cut off).
struct LegacyImportView: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let palette: MiraThemePalette

    private enum Phase: Equatable {
        case choose
        case reading(done: Int, total: Int)
        case review
        case finished(count: Int)
    }

    @State private var phase: Phase = .choose
    @State private var pickedPhotos: [PhotosPickerItem] = []
    @State private var showFileImporter = false
    @State private var showGeminiSettings = false
    @State private var candidates: [ImportCandidate] = []
    @State private var failures: [String] = []
    @State private var hasKey = GeminiSettingsStore.shared.hasKey

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .miraScreenBackground(palette)
            .navigationTitle("カレンダーの引っ越し")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showGeminiSettings = true } label: { Image(systemName: "key.fill") }
                        .accessibilityLabel("Geminiの設定")
                }
            }
            .sheet(isPresented: $showGeminiSettings, onDismiss: { hasKey = GeminiSettingsStore.shared.hasKey }) {
                GeminiSettingsSheet(palette: palette)
            }
            .onChange(of: pickedPhotos) { _, items in
                guard !items.isEmpty else { return }
                Task { await readPhotos(items) }
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.pdf, .image], allowsMultipleSelection: true) { result in
                if case .success(let urls) = result { Task { await readFiles(urls) } }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .choose: chooser
        case .reading(let done, let total): reading(done: done, total: total)
        case .review: review
        case .finished(let count): finished(count)
        }
    }

    // MARK: - Choose

    private var chooser: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MiraSpacing.lg) {
                VStack(alignment: .leading, spacing: MiraSpacing.xs) {
                    Text("前のカレンダーの予定を、写真から引っ越し")
                        .font(.title3.bold())
                        .foregroundStyle(palette.primaryText)
                    Text("カレンダー画面のスクショや、PC画面を撮った写真を選ぶと、Miraが予定を読み取ります。追加する前に、ひとつずつ確認できます。")
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: MiraSpacing.sm) {
                    tip("1", "PC版のYahoo!カレンダーを月表示で開く（予定名が省略されません）")
                    tip("2", "1か月ずつ、画面全体が入るように撮る。斜めでもOK")
                    tip("3", "何枚でもまとめて選べます")
                }
                .miraCard(palette)

                if !hasKey {
                    Button { showGeminiSettings = true } label: {
                        Label("先にGeminiのAPIキーを設定してね", systemImage: "key.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(palette.warning.opacity(0.15), in: RoundedRectangle(cornerRadius: MiraRadius.small))
                    }
                    .foregroundStyle(palette.warning)
                }

                PhotosPicker(selection: $pickedPhotos, maxSelectionCount: 24, matching: .images) {
                    Label("写真・スクショを選ぶ", systemImage: "photo.on.rectangle.angled")
                        .font(.headline)
                        .foregroundStyle(palette.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(palette.accent, in: RoundedRectangle(cornerRadius: MiraRadius.medium))
                }
                .disabled(!hasKey)
                .accessibilityIdentifier("importPickPhotos")

                Button { showFileImporter = true } label: {
                    Label("PDF・画像ファイルを選ぶ", systemImage: "doc.richtext")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: MiraRadius.medium))
                }
                .foregroundStyle(palette.accent)
                .disabled(!hasKey)

                Text("画像はGoogleのGeminiに送られて読み取られます。読み取りが終わると、予定はこのiPhoneの中だけに保存されます。")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            }
            .padding(MiraSpacing.md)
        }
    }

    private func tip(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: MiraSpacing.sm) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.onAccent)
                .frame(width: 22, height: 22)
                .background(palette.accent, in: Circle())
            Text(text)
                .font(.subheadline)
                .foregroundStyle(palette.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Reading

    private func reading(done: Int, total: Int) -> some View {
        VStack(spacing: MiraSpacing.md) {
            if store.theme == .pixelCat {
                PixelCatView(mood: .thinking, size: 96)
            }
            ProgressView(value: Double(done), total: Double(max(total, 1)))
                .tint(palette.accent)
                .frame(maxWidth: 240)
            Text("\(done) / \(total)枚 読み取り中…")
                .font(.headline.monospacedDigit())
                .foregroundStyle(palette.primaryText)
            Text("1枚に数十秒かかることがあるにゃ")
                .font(.caption)
                .foregroundStyle(palette.secondaryText)
        }
        .padding(MiraSpacing.lg)
    }

    private func readPhotos(_ items: [PhotosPickerItem]) async {
        var images: [Data] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                images.append(contentsOf: ImportImagePreparer.jpegs(fromImageData: data))
            }
        }
        pickedPhotos = []
        await read(images)
    }

    private func readFiles(_ urls: [URL]) async {
        var images: [Data] = []
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            if url.pathExtension.lowercased() == "pdf" {
                images.append(contentsOf: ImportImagePreparer.jpegs(fromPDF: url))
            } else if let data = try? Data(contentsOf: url) {
                images.append(contentsOf: ImportImagePreparer.jpegs(fromImageData: data))
            }
        }
        await read(images)
    }

    private func read(_ images: [Data]) async {
        guard !images.isEmpty else {
            failures = ["画像を読み込めませんでした"]
            return
        }
        failures = []
        var found: [ImportCandidate] = []
        let extractor = GeminiCalendarExtractor()
        for (index, image) in images.enumerated() {
            phase = .reading(done: index, total: images.count)
            do {
                found += try await extractor.extract(image: image, sourceIndex: index, today: store.now)
            } catch {
                failures.append("\(index + 1)枚目：\(error.localizedDescription)")
            }
        }
        let colored = found.sorted { $0.start < $1.start }.map { candidate -> ImportCandidate in
            var value = candidate
            value.colorTag = store.suggestedColor(forTitle: candidate.title) ?? store.colorProfile.fallbackColor
            return value
        }
        candidates = ImportCandidateBuilder.markDuplicates(colored, existing: store.items)
        phase = candidates.isEmpty && !failures.isEmpty ? .choose : .review
        if candidates.isEmpty && failures.isEmpty { failures = ["予定が見つかりませんでした"] }
    }

    // MARK: - Review

    private var review: some View {
        VStack(spacing: 0) {
            List {
                if !failures.isEmpty {
                    Section {
                        ForEach(failures, id: \.self) { failure in
                            Label(failure, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(palette.warning)
                        }
                    }
                }
                Section {
                    HStack {
                        Text("\(selectedCount)件を追加 / 全\(candidates.count)件")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Button(allSelected ? "全部外す" : "全部選ぶ") { toggleAll() }
                            .font(.subheadline)
                    }
                } footer: {
                    Text("すでにある予定と同じものは最初から外してあります。色は予定名から自動で付けました。")
                }
                ForEach(groupedDays, id: \.self) { day in
                    Section(day.japaneseShortDate) {
                        ForEach($candidates) { $candidate in
                            if Calendar.mira.isDate(candidate.start, inSameDayAs: day) {
                                ImportCandidateRow(candidate: $candidate, palette: palette)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)

            Button {
                let added = store.importCandidates(candidates)
                phase = .finished(count: added)
            } label: {
                Text("\(selectedCount)件をカレンダーに追加")
                    .font(.headline)
                    .foregroundStyle(palette.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(selectedCount > 0 ? palette.accent : palette.secondaryText.opacity(0.4), in: RoundedRectangle(cornerRadius: MiraRadius.medium))
            }
            .disabled(selectedCount == 0)
            .padding(MiraSpacing.md)
            .background(.bar)
            .accessibilityIdentifier("importCommit")
        }
    }

    private var groupedDays: [Date] {
        var days: [Date] = []
        for candidate in candidates {
            let day = Calendar.mira.startOfDay(for: candidate.start)
            if days.last != day && !days.contains(day) { days.append(day) }
        }
        return days
    }

    private var selectedCount: Int { candidates.filter(\.isSelected).count }
    private var allSelected: Bool { !candidates.isEmpty && candidates.allSatisfy(\.isSelected) }

    private func toggleAll() {
        let target = !allSelected
        for index in candidates.indices { candidates[index].isSelected = target }
    }

    // MARK: - Finished

    private func finished(_ count: Int) -> some View {
        VStack(spacing: MiraSpacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(palette.success)
            Text("\(count)件を引っ越したにゃ")
                .font(.title3.bold())
                .foregroundStyle(palette.primaryText)
            Text("間違いがあれば、画面下の「取り消す」でまとめて戻せます。続けて別の月も取り込めます。")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
            Button("続けて取り込む") {
                candidates = []
                failures = []
                phase = .choose
            }
            .font(.headline)
            .frame(minHeight: 44)
            Button("閉じる") { dismiss() }
                .frame(minHeight: 44)
        }
        .padding(MiraSpacing.lg)
    }
}

private struct ImportCandidateRow: View {
    @Environment(MiraStore.self) private var store
    @Binding var candidate: ImportCandidate
    let palette: MiraThemePalette

    var body: some View {
        HStack(spacing: MiraSpacing.sm) {
            Button {
                candidate.isSelected.toggle()
            } label: {
                Image(systemName: candidate.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(candidate.isSelected ? palette.accent : palette.secondaryText)
                    .frame(width: 32, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(candidate.isSelected ? "追加する" : "追加しない")

            VStack(alignment: .leading, spacing: 3) {
                TextField("予定名", text: $candidate.title)
                    .font(.subheadline.weight(.semibold))
                Text(timeText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(palette.secondaryText)
                HStack(spacing: 6) {
                    if let duplicate = candidate.duplicateOf {
                        badge("登録済み：\(duplicate)", palette.secondaryText)
                    }
                    if candidate.needsReview {
                        badge("要確認", palette.warning)
                    }
                }
            }

            Spacer(minLength: 0)

            Menu {
                ForEach(EventColorTag.allCases) { tag in
                    Button(store.label(for: tag).map { "\($0)（\(tag.title)）" } ?? tag.title) { candidate.colorTag = tag }
                }
                Button("色なし") { candidate.colorTag = nil }
            } label: {
                Circle()
                    .fill(candidate.colorTag.map(palette.swatch(for:)) ?? palette.secondaryText.opacity(0.2))
                    .overlay { Circle().strokeBorder(palette.primaryText.opacity(0.2), lineWidth: 1) }
                    .frame(width: 26, height: 26)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("色：\(candidate.colorTag.map(store.displayName(for:)) ?? "なし")")
        }
        .opacity(candidate.isSelected ? 1 : 0.55)
    }

    private var timeText: String {
        let calendar = Calendar.mira
        let lastDay = candidate.end.addingTimeInterval(-1)
        let span = calendar.isDate(candidate.start, inSameDayAs: lastDay) ? "" : "〜\(lastDay.japaneseShortDate)"
        if candidate.isAllDay { return "終日\(span)" }
        let style = Date.FormatStyle.mira.hour().minute()
        return "\(candidate.start.formatted(style))–\(candidate.end.formatted(style))\(span)"
    }

    private func badge(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
    }
}

// PERSONAL BUILD ONLY — remove before submitting to the App Store.
struct GeminiSettingsSheet: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let palette: MiraThemePalette

    @State private var key = ""
    @State private var model = GeminiSettingsStore.shared.model
    @State private var message: String?
    @State private var hasKey = GeminiSettingsStore.shared.hasKey

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField(hasKey ? "保存済み（変更するときだけ入力）" : "APIキー", text: $key)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("モデル", text: $model)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Gemini")
                } footer: {
                    Text("キーはこのiPhoneのキーチェーンにだけ保存されます。モデルの初期値は \(GeminiSettingsStore.defaultModel) です。")
                }
                Section {
                    Toggle("ミラ用の色ルール", isOn: Binding(
                        get: { store.colorProfile == .mira },
                        set: { store.setColorProfile($0 ? .mira : .standard) }
                    ))
                } footer: {
                    Text("ふだんはアカウントで自動的に切り替わります。この端末で試すとき用です。")
                }
                if hasKey {
                    Section {
                        Button("保存したキーを削除", role: .destructive) {
                            GeminiSettingsStore.shared.removeKey()
                            hasKey = false
                        }
                    }
                }
                if let message {
                    Text(message).font(.caption).foregroundStyle(palette.warning)
                }
            }
            .navigationTitle("Geminiの設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        GeminiSettingsStore.shared.setModel(model)
                        if !key.isEmpty {
                            guard GeminiSettingsStore.shared.saveKey(key) else {
                                message = "キーを保存できませんでした。形式を確認してね。"
                                return
                            }
                        }
                        dismiss()
                    }
                }
            }
        }
        .tint(palette.accent)
    }
}
