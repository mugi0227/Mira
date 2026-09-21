import SwiftUI

struct MiraQuickInputBar: View {
    @Environment(MiraStore.self) private var store
    let palette: MiraThemePalette
    var isFocused: FocusState<Bool>.Binding

    @State private var isSending = false
    @State private var showContextPicker = false
    @State private var showConversationHistory = false

    var body: some View {
        VStack(alignment: .leading, spacing: MiraSpacing.xs) {
            if let context = store.pinnedContext {
                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .font(.caption)
                    Text(context.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Button {
                        store.pinContext(nil)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                    }
                    .accessibilityLabel("案件指定を外す")
                }
                .foregroundStyle(palette.accent)
                .padding(.horizontal, 10)
                .frame(minHeight: 30)
                .background(palette.accentSoft, in: Capsule())
                .accessibilityIdentifier("pinnedContextChip")
            }

            HStack(spacing: MiraSpacing.xs) {
                Button {
                    isFocused.wrappedValue = false
                    showContextPicker = true
                } label: {
                    Image(systemName: "scope")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(palette.isCatSkin || store.pinnedContext != nil ? palette.accent : palette.secondaryText)
                        .background(palette.surface, in: Circle())
                }
                .accessibilityLabel("この話について予定を指定")
                .accessibilityIdentifier("contextPickerButton")

                TextField("Miraに雑に投げる…", text: Binding(
                    get: { store.quickInputText },
                    set: { store.quickInputText = $0 }
                ), axis: .vertical)
                    .lineLimit(1...4)
                    .textInputAutocapitalization(.never)
                    .focused(isFocused)
                    .submitLabel(.send)
                    .onSubmit(send)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .foregroundStyle(palette.primaryText)
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: palette.isCatSkin ? 24 : MiraRadius.medium, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: palette.isCatSkin ? 24 : MiraRadius.medium, style: .continuous)
                            .stroke(palette.isCatSkin ? palette.accent.opacity(0.14) : palette.primaryText.opacity(0.07), lineWidth: 1)
                    }
                    .accessibilityLabel("Miraへのお願い")
                    .accessibilityIdentifier("miraQuickInput")

                Button(action: send) {
                    if store.isInterpretingConversation {
                        ProgressView()
                            .tint(palette.onAccent)
                            .frame(width: 44, height: 44)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 17, weight: .bold))
                            .frame(width: 44, height: 44)
                    }
                }
                .foregroundStyle(palette.onAccent)
                .background {
                    if palette.isCatSkin {
                        Circle().fill(palette.actionGradient)
                            .opacity(canSend ? 1 : 0.45)
                    } else {
                        Circle().fill(canSend ? palette.accent : palette.secondaryText.opacity(0.35))
                    }
                }
                .buttonStyle(MiraPressStyle())
                .disabled(!canSend)
                .accessibilityLabel("Miraへ送る")
                .accessibilityIdentifier("miraSendButton")
            }

            HStack {
                Text(store.quickInputText.isEmpty ? "例：来週、友達とご飯の日を探して" : "書きかけの内容は自動で残ります")
                    .font(.caption2)
                    .foregroundStyle(palette.secondaryText)
                Spacer()
                if store.activeConversationCaseID != nil {
                    Button("会話を見る") { showConversationHistory = true }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.accent)
                        .frame(minHeight: 30)
                }
            }
        }
        .modifier(QuickInputSurface(palette: palette))
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完了") {
                    isFocused.wrappedValue = false
                }
            }
        }
        .sheet(isPresented: $showContextPicker) {
            ContextPickerSheet(palette: palette)
        }
        .sheet(isPresented: $showConversationHistory) {
            ConversationHistorySheet(palette: palette, caseID: store.activeConversationCaseID)
        }
    }

    private var canSend: Bool {
        !store.quickInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !store.isInterpretingConversation && !isSending
    }

    private func send() {
        guard canSend else { return }
        let original = store.quickInputText
        let value = original.trimmingCharacters(in: .whitespacesAndNewlines)
        isSending = true
        isFocused.wrappedValue = false
        Task {
            let saved = await store.handleConversationInput(value)
            // Do not discard a newer thought typed while the assistant was working.
            if saved, store.quickInputText == original, store.persistenceIssue == nil, store.draftPersistenceIssue == nil {
                store.quickInputText = ""
            }
            isSending = false
        }
    }
}

private struct QuickInputSurface: ViewModifier {
    let palette: MiraThemePalette

    @ViewBuilder
    func body(content: Content) -> some View {
        if palette.isCatSkin {
            content.miraCard(palette, padding: MiraSpacing.sm)
        } else {
            content
                .padding(MiraSpacing.sm)
                .background(palette.elevatedBackground, in: RoundedRectangle(cornerRadius: MiraRadius.large, style: .continuous))
                .shadow(color: palette.shadow, radius: 12, y: 5)
        }
    }
}

struct ContextPickerSheet: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let palette: MiraThemePalette

    @State private var query = ""
    @State private var selectedKind: ConversationCaseKind = .adjustment
    @State private var includePast = false

    var body: some View {
        NavigationStack {
            VStack(spacing: MiraSpacing.sm) {
                Picker("種類", selection: $selectedKind) {
                    Text("進行中").tag(ConversationCaseKind.adjustment)
                    Text("検討中").tag(ConversationCaseKind.invitation)
                    Text("確定予定").tag(ConversationCaseKind.confirmedEvent)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, MiraSpacing.md)
                .accessibilityIdentifier("contextKindPicker")

                List {
                    if results.isEmpty {
                        ContentUnavailableView(
                            "該当する予定がありません",
                            systemImage: "calendar.badge.questionmark",
                            description: Text(includePast ? "検索語を変えてみてください" : "必要なら「過去も検索」をONにできます")
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(results) { result in
                            Button {
                                store.pinContext(result)
                                dismiss()
                            } label: {
                                HStack(spacing: MiraSpacing.sm) {
                                    Image(systemName: symbol(for: result.kind))
                                        .foregroundStyle(palette.accent)
                                        .frame(width: 30)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(result.title)
                                            .font(.headline)
                                            .foregroundStyle(palette.primaryText)
                                        Text(result.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(palette.secondaryText)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(palette.secondaryText)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(palette.surface)
                            .accessibilityIdentifier("contextResult-\(result.id.uuidString)")
                        }
                    }
                }
                .listStyle(.plain)
                .miraFormStyle(palette)
            }
            .miraScreenBackground(palette)
            .navigationTitle("この話について")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "案件・予定を検索")
            .safeAreaInset(edge: .bottom) {
                Toggle("過去も検索", isOn: $includePast)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, MiraSpacing.md)
                    .frame(minHeight: 52)
                    .background(.regularMaterial)
                    .accessibilityIdentifier("includePastToggle")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .tint(palette.accent)
    }

    private var results: [ContextSearchResult] {
        store.searchContexts(query: query, kind: selectedKind, includePast: includePast)
    }

    private func symbol(for kind: ConversationCaseKind) -> String {
        switch kind {
        case .adjustment: "calendar.badge.clock"
        case .invitation: "questionmark.bubble"
        case .confirmedEvent: "calendar.badge.checkmark"
        case .draft: "square.and.pencil"
        }
    }
}

struct ConversationHistorySheet: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let palette: MiraThemePalette
    let caseID: UUID?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: MiraSpacing.sm) {
                    if turns.isEmpty {
                        EmptyStateView(
                            symbol: "bubble.left.and.bubble.right",
                            title: "まだ会話はありません",
                            message: "ホームの入力欄から雑に頼めます。",
                            palette: palette
                        )
                    } else {
                        ForEach(turns) { turn in
                            HStack {
                                if turn.role == .user { Spacer(minLength: 36) }
                                Text(turn.text)
                                    .font(.subheadline)
                                    .foregroundStyle(turn.role == .user ? palette.onAccent : palette.primaryText)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        turn.role == .user ? palette.accent : palette.surface,
                                        in: RoundedRectangle(cornerRadius: MiraRadius.medium, style: .continuous)
                                    )
                                if turn.role == .assistant { Spacer(minLength: 36) }
                            }
                        }
                    }
                }
                .padding(MiraSpacing.md)
            }
            .miraScreenBackground(palette)
            .navigationTitle(store.conversationCase(id: caseID)?.title ?? "Miraとの会話")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .tint(palette.accent)
    }

    private var turns: [ConversationTurnSnapshot] {
        store.conversationTurns(caseID: caseID)
    }
}
