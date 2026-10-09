import SwiftUI
import UIKit

/// Chat with Mira. Replies stream in, show what Mira checked, and carry cards
/// that only change the calendar when tapped.
struct MiraChatView: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let palette: MiraThemePalette

    @State private var draft = ""
    @FocusState private var isInputFocused: Bool

    private let suggestions = [
        "今週の予定は？",
        "来週、友達とご飯に行ける日を探して",
        "土曜の誘いを断る文を作って",
        "今月ちゃんと休めてる？"
    ]

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: MiraSpacing.md) {
                        if store.chatMessages.isEmpty {
                            welcome
                        }
                        ForEach(store.chatMessages) { message in
                            ChatBubble(message: message, palette: palette)
                                .id(message.id)
                        }
                        Color.clear.frame(height: 1).id("chat-bottom")
                    }
                    .padding(MiraSpacing.md)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: store.chatMessages) { _, _ in
                    withAnimation(reduceMotion ? nil : MiraMotion.quick) {
                        proxy.scrollTo("chat-bottom", anchor: .bottom)
                    }
                }
                .onAppear {
                    store.restoreChatIfNeeded()
                    proxy.scrollTo("chat-bottom", anchor: .bottom)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { composer }
            .miraScreenBackground(palette)
            .navigationTitle("Mira")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !store.chatMessages.isEmpty {
                        Button {
                            store.resetChat()
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                        .accessibilityLabel("新しい会話")
                        .disabled(store.isChatResponding)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .tint(palette.accent)
        .presentationDragIndicator(.visible)
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: MiraSpacing.md) {
            HStack(alignment: .center, spacing: MiraSpacing.sm) {
                MiraAvatar(palette: palette, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.currentAssistantMessage.title)
                        .font(.headline)
                        .foregroundStyle(palette.primaryText)
                    Text(store.currentAssistantMessage.body)
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text("予定のこと、なんでも話しかけてね。カレンダーを見てから答えるにゃ。決めるのはあなた。")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
            VStack(alignment: .leading, spacing: MiraSpacing.xs) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        send(suggestion)
                    } label: {
                        Text(suggestion)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.accent)
                            .padding(.horizontal, MiraSpacing.sm)
                            .frame(minHeight: 40)
                            .background(palette.accentSoft.opacity(0.6), in: Capsule())
                    }
                    .buttonStyle(MiraPressStyle())
                    .accessibilityIdentifier("chatSuggestion")
                }
            }
        }
        .padding(.top, MiraSpacing.sm)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: MiraSpacing.xs) {
            TextField("Miraに話しかける…", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .focused($isInputFocused)
                .submitLabel(.send)
                .onSubmit { send(draft) }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(minHeight: 44)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(palette.primaryText.opacity(0.08), lineWidth: 1)
                }
                .accessibilityIdentifier("miraChatInput")

            Button { send(draft) } label: {
                Group {
                    if store.isChatResponding {
                        ProgressView().tint(palette.onAccent)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 17, weight: .bold))
                    }
                }
                .foregroundStyle(palette.onAccent)
                .frame(width: 44, height: 44)
                .background(Circle().fill(canSend || store.isChatResponding ? palette.accent : palette.secondaryText.opacity(0.35)))
            }
            .buttonStyle(MiraPressStyle())
            .disabled(!canSend)
            .accessibilityLabel("送る")
            .accessibilityIdentifier("miraChatSend")
        }
        .padding(.horizontal, MiraSpacing.md)
        .padding(.vertical, MiraSpacing.xs)
        .background(.bar)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !store.isChatResponding
    }

    private func send(_ text: String) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !store.isChatResponding else { return }
        draft = ""
        Task { await store.sendChat(value) }
    }
}

struct MiraAvatar: View {
    @Environment(MiraStore.self) private var store
    let palette: MiraThemePalette
    var size: CGFloat = 32
    var mood: CatMood = .happy

    var body: some View {
        ZStack {
            Circle().fill(palette.elevatedSurface)
            if store.theme == .pixelCat {
                PixelCatView(mood: mood, size: size * 0.9)
            } else {
                Image(systemName: "leaf.fill")
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(palette.accent)
            }
        }
        .frame(width: size, height: size)
        .overlay { Circle().strokeBorder(palette.accent.opacity(0.2), lineWidth: 1) }
        .accessibilityHidden(true)
    }
}

private struct ChatBubble: View {
    @Environment(MiraStore.self) private var store
    let message: ChatMessage
    let palette: MiraThemePalette

    var body: some View {
        if message.role == .user {
            HStack {
                Spacer(minLength: 48)
                Text(message.text)
                    .font(.body)
                    .foregroundStyle(palette.onAccent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(palette.accent, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .textSelection(.enabled)
            }
        } else {
            HStack(alignment: .top, spacing: MiraSpacing.xs) {
                MiraAvatar(palette: palette, size: 32, mood: message.isStreaming ? .thinking : .happy)
                VStack(alignment: .leading, spacing: MiraSpacing.xs) {
                    if !message.activities.isEmpty {
                        ActivityTrail(activities: message.activities, palette: palette)
                    }
                    if message.text.isEmpty && message.isStreaming {
                        TypingIndicator(palette: palette)
                    } else if !message.text.isEmpty {
                        Text(message.text)
                            .font(.body)
                            .foregroundStyle(palette.primaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(palette.primaryText.opacity(0.06), lineWidth: 1)
                            }
                            .textSelection(.enabled)
                            .accessibilityIdentifier(message.isStreaming ? "chatAssistantStreaming" : "chatAssistantText")
                    }
                    ForEach(message.cards) { card in
                        ChatCardView(card: card, messageID: message.id, palette: palette)
                    }
                }
                Spacer(minLength: 24)
            }
            .accessibilityElement(children: .contain)
        }
    }
}

private struct ActivityTrail: View {
    let activities: [ChatActivity]
    let palette: MiraThemePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(activities) { activity in
                Label(activity.text, systemImage: activity.symbol)
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            }
        }
        .padding(.horizontal, MiraSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Miraが確認したこと：" + activities.map(\.text).joined(separator: "、"))
    }
}

private struct TypingIndicator: View {
    let palette: MiraThemePalette
    @State private var phase = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(palette.secondaryText.opacity(0.6))
                    .frame(width: 7, height: 7)
                    .opacity(reduceMotion ? 0.7 : 0.35 + 0.65 * abs(sin(phase + Double(index) * 0.6)))
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { phase = .pi }
        }
        .accessibilityLabel("Miraが考え中")
    }
}

private struct ChatCardView: View {
    @Environment(MiraStore.self) private var store
    let card: ChatCard
    let messageID: UUID
    let palette: MiraThemePalette

    var body: some View {
        Group {
            switch card {
            case .schedule(let summary): scheduleCard(summary)
            case .openSlots(let slots): slotsCard(slots)
            case .eventProposal(let proposal): eventCard(proposal)
            case .moveProposal(let proposal): moveCard(proposal)
            case .message(let draft): messageCard(draft)
            case .balance(let balance): balanceCard(balance)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .miraCard(palette, padding: MiraSpacing.sm)
    }

    private func scheduleCard(_ summary: ChatScheduleSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(summary.title, systemImage: "calendar")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.secondaryText)
            ForEach(summary.items) { item in
                HStack(spacing: MiraSpacing.xs) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(item.colorTag.map(palette.swatch(for:)) ?? palette.color(for: item))
                        .frame(width: 4, height: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.primaryText)
                            .lineLimit(1)
                        Text("\(item.startDate.japaneseShortDate) \(item.timeDescription)")
                            .font(.caption)
                            .foregroundStyle(palette.secondaryText)
                    }
                    Spacer(minLength: 0)
                    if item.kind == .margin {
                        Image(systemName: item.marginKind?.symbolName ?? "leaf.fill")
                            .font(.caption)
                            .foregroundStyle(palette.accent)
                            .accessibilityLabel("余白")
                    }
                }
            }
        }
    }

    private func slotsCard(_ value: ChatOpenSlots) -> some View {
        VStack(alignment: .leading, spacing: MiraSpacing.xs) {
            Label("余白を守れる候補", systemImage: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.secondaryText)
            ForEach(value.slots) { slot in
                Button {
                    Task { await proposeFromSlot(slot, purpose: value.purpose) }
                } label: {
                    HStack {
                        Image(systemName: slot.band.symbolName)
                            .foregroundStyle(palette.accent)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(slot.start.japaneseShortDate) \(slot.band.title)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(palette.primaryText)
                            Text("\(slot.start.formatted(Date.FormatStyle.mira.hour().minute()))–\(slot.end.formatted(Date.FormatStyle.mira.hour().minute()))")
                                .font(.caption)
                                .foregroundStyle(palette.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(palette.accent)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(MiraPressStyle())
                .accessibilityHint("この枠で予定の案を作る")
            }
        }
    }

    private func proposeFromSlot(_ slot: ChatOpenSlot, purpose: String) async {
        let title = purpose.isEmpty ? "予定" : purpose
        let result = await store.toolProposeEvent(title: title, start: slot.start, end: slot.end, isAllDay: slot.band == .allDay)
        store.chatMessages.append(ChatMessage(
            role: .assistant,
            text: "\(slot.start.japaneseShortDate)\(slot.band.title)の案だにゃ。",
            activities: [result.activity],
            cards: result.card.map { [$0] } ?? [],
            createdAt: store.now
        ))
    }

    private func eventCard(_ proposal: ChatEventProposal) -> some View {
        VStack(alignment: .leading, spacing: MiraSpacing.xs) {
            Label("予定の案", systemImage: "calendar.badge.plus")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.secondaryText)
            HStack(spacing: MiraSpacing.xs) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(proposal.event.colorTag.map(palette.swatch(for:)) ?? palette.accent)
                    .frame(width: 4, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(proposal.event.title)
                        .font(.headline)
                        .foregroundStyle(palette.primaryText)
                    Text("\(proposal.event.startDate.japaneseShortDate) \(proposal.event.timeDescription)・負荷 \(proposal.event.loadClass.title)")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                }
            }
            impactLines(conflicts: proposal.conflicts, margins: proposal.impact.overlappingMargins)
            proposalActions(state: proposal.state, needsCare: proposal.needsCare, applyTitle: "カレンダーに追加", appliedTitle: "追加しました", cardID: proposal.id)
        }
    }

    private func moveCard(_ proposal: ChatMoveProposal) -> some View {
        VStack(alignment: .leading, spacing: MiraSpacing.xs) {
            Label("移動の案", systemImage: "arrow.left.arrow.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.secondaryText)
            Text(proposal.preview.title)
                .font(.headline)
                .foregroundStyle(palette.primaryText)
            HStack(spacing: 6) {
                Text(proposal.preview.before.startDate.japaneseShortDate)
                    .strikethrough()
                    .foregroundStyle(palette.secondaryText)
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(palette.accent)
                Text(proposal.preview.after.startDate.japaneseShortDate)
                    .fontWeight(.semibold)
                    .foregroundStyle(palette.primaryText)
            }
            .font(.subheadline)
            impactLines(conflicts: proposal.preview.conflicts, margins: proposal.preview.impact.overlappingMargins)
            proposalActions(state: proposal.state, needsCare: proposal.needsCare, applyTitle: "この日に動かす", appliedTitle: "動かしました", cardID: proposal.id)
        }
    }

    @ViewBuilder
    private func impactLines(conflicts: [String], margins: [CalendarItemSnapshot]) -> some View {
        let notes = conflicts + margins.map { "余白「\($0.title)」と重なります" }
        if notes.isEmpty {
            Label("余白も他の予定も守れるにゃ", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(palette.success)
        } else {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(notes, id: \.self) { note in
                    Label(note, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(palette.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private func proposalActions(state: ChatProposalState, needsCare: Bool, applyTitle: String, appliedTitle: String, cardID: UUID) -> some View {
        switch state {
        case .pending:
            HStack(spacing: MiraSpacing.xs) {
                Button {
                    store.applyChatCard(messageID: messageID, cardID: cardID)
                } label: {
                    Text(needsCare ? "それでも\(applyTitle)" : applyTitle)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(needsCare ? palette.warning : palette.accent, in: RoundedRectangle(cornerRadius: MiraRadius.small, style: .continuous))
                }
                .buttonStyle(MiraPressStyle())
                .accessibilityIdentifier("chatApplyCard")
                Button("やめる") { store.dismissChatCard(messageID: messageID, cardID: cardID) }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
                    .frame(minWidth: 64, minHeight: 44)
            }
        case .applied:
            Label(appliedTitle, systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.success)
        case .dismissed:
            Label("見送りました", systemImage: "xmark.circle")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
        }
    }

    private func messageCard(_ draft: ChatMessageDraft) -> some View {
        VStack(alignment: .leading, spacing: MiraSpacing.xs) {
            Label("\(draft.purpose)の文面", systemImage: "text.bubble")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.secondaryText)
            Text(draft.text)
                .font(.body)
                .foregroundStyle(palette.primaryText)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: MiraSpacing.xs) {
                Button {
                    UIPasteboard.general.string = draft.text
                    store.toast = "コピーしたにゃ"
                } label: {
                    Label("コピー", systemImage: "doc.on.doc")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: MiraRadius.small, style: .continuous))
                }
                .buttonStyle(MiraPressStyle())
                ShareLink(item: draft.text) {
                    Label("送る", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: MiraRadius.small, style: .continuous))
                }
            }
            .foregroundStyle(palette.accent)
        }
    }

    private func balanceCard(_ balance: ChatBalanceSummary) -> some View {
        VStack(alignment: .leading, spacing: MiraSpacing.xs) {
            Label("\(balance.month.japaneseMonthTitle)の余白", systemImage: "leaf")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.secondaryText)
            ForEach(balance.lines, id: \.kind) { line in
                HStack(spacing: MiraSpacing.xs) {
                    Image(systemName: line.kind.symbolName)
                        .foregroundStyle(palette.accent)
                        .frame(width: 20)
                    Text(line.kind.title)
                        .font(.subheadline)
                        .foregroundStyle(palette.primaryText)
                    Spacer()
                    ProgressView(value: Double(min(line.current, max(line.target, 1))), total: Double(max(line.target, 1)))
                        .tint(line.current >= line.target ? palette.success : palette.accent)
                        .frame(width: 80)
                    Text("\(line.current)/\(line.target)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(palette.secondaryText)
                        .frame(width: 36, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
