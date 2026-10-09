import SwiftUI

/// Mira sits quietly in the corner and only speaks up when something needs
/// attention, so the calendar stays the first thing you see.
struct MiraCompanionButton: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let message: AssistantMessage
    let palette: MiraThemePalette
    let action: () -> Void

    @State private var dismissedBubbleTitle: String?

    var body: some View {
        HStack(alignment: .bottom, spacing: MiraSpacing.xs) {
            if showsBubble {
                bubble
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.85, anchor: .bottomTrailing).combined(with: .opacity))
            }
            avatar
        }
        .animation(reduceMotion ? nil : MiraMotion.standard, value: showsBubble)
    }

    private var needsAttention: Bool {
        message.actionTitle != nil || message.mood == .warning
    }

    private var showsBubble: Bool {
        needsAttention && dismissedBubbleTitle != message.title
    }

    private var bubble: some View {
        HStack(alignment: .top, spacing: 4) {
            Button(action: action) {
                Text(message.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primaryText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 32, alignment: .leading)
            }
            .buttonStyle(.plain)
            Button {
                dismissedBubbleTitle = message.title
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(palette.secondaryText)
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("吹き出しを閉じる")
        }
        .padding(.leading, MiraSpacing.sm)
        .padding(.vertical, 6)
        .frame(maxWidth: 230, alignment: .leading)
        .background(palette.elevatedSurface, in: RoundedRectangle(cornerRadius: MiraRadius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MiraRadius.medium, style: .continuous)
                .strokeBorder(message.mood == .warning ? palette.warning.opacity(0.45) : palette.primaryText.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: palette.shadow, radius: 12, y: 4)
        .padding(.bottom, 14)
        .accessibilityElement(children: .contain)
    }

    private var avatar: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(palette.elevatedSurface)
                    .overlay { Circle().strokeBorder(palette.accent.opacity(0.25), lineWidth: 1.5) }
                    .shadow(color: palette.shadow, radius: 14, y: 5)
                if store.theme == .pixelCat {
                    PixelCatView(mood: message.mood, size: 54)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: "bubble.left.and.text.bubble.right.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(palette.accent)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: 64, height: 64)
            .overlay(alignment: .topTrailing) {
                if needsAttention {
                    Circle()
                        .fill(message.mood == .warning ? palette.warning : palette.accent)
                        .frame(width: 12, height: 12)
                        .overlay { Circle().strokeBorder(palette.elevatedSurface, lineWidth: 2) }
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(MiraPressStyle())
        .accessibilityLabel(needsAttention ? "Miraに話しかける。お知らせがあります" : "Miraに話しかける")
        .accessibilityIdentifier("miraCompanionButton")
    }
}

/// Talking to Mira: what it noticed, plus the free-form input.
struct MiraCompanionSheet: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let palette: MiraThemePalette

    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MiraSpacing.md) {
                    AssistantCard(message: store.currentAssistantMessage, palette: palette) {
                        dismiss()
                        if store.activeRebalanceProposal != nil {
                            Task {
                                try? await Task.sleep(for: .milliseconds(400))
                                store.isRebalanceProposalPresented = true
                            }
                        } else {
                            store.autoPlaceMargins(for: store.selectedMonth)
                        }
                    }

                    MiraQuickInputBar(palette: palette, isFocused: $isInputFocused) {
                        // Results open as their own sheets, so step aside first.
                        dismiss()
                        try? await Task.sleep(for: .milliseconds(400))
                    }
                }
                .padding(MiraSpacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .miraScreenBackground(palette)
            .navigationTitle("Mira")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .tint(palette.accent)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            // Jump straight to typing unless Mira has something to show first.
            let message = store.currentAssistantMessage
            if message.actionTitle == nil && message.mood != .warning { isInputFocused = true }
        }
    }
}
