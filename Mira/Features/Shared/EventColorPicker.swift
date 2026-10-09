import SwiftUI

/// Seven hues in three tones plus white, gray and black. Tap to choose,
/// long-press to give a color your own label (shown under the dot).
struct EventColorPicker: View {
    @Environment(MiraStore.self) private var store
    @Binding var selection: EventColorTag?
    let palette: MiraThemePalette
    var onPick: ((EventColorTag?) -> Void)?

    @State private var renaming: EventColorTag?
    @State private var labelDraft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 2) {
                ForEach(EventColorTag.allCases) { tag in
                    option(tag)
                }
                noneOption
            }
            Text("長押しでラベルを付けられます")
                .font(.caption2)
                .foregroundStyle(palette.secondaryText)
        }
        .padding(.vertical, 2)
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("予定の色")
        .alert("色のラベル", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("例：遊び", text: $labelDraft)
            Button("保存") {
                if let renaming { store.setLabel(labelDraft, for: renaming) }
                renaming = nil
            }
            Button("キャンセル", role: .cancel) { renaming = nil }
        } message: {
            Text(renaming.map { "「\($0.title)」に付ける名前（空にすると外れます）" } ?? "")
        }
    }

    private func option(_ tag: EventColorTag) -> some View {
        let label = store.label(for: tag)
        return Button { pick(tag) } label: {
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .fill(palette.swatch(for: tag))
                        .overlay {
                            if tag.needsOutline || tag.tone == .light {
                                Circle().strokeBorder(palette.primaryText.opacity(0.18), lineWidth: 1)
                            }
                        }
                        .frame(width: 26, height: 26)
                    if selection == tag {
                        Image(systemName: "checkmark")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(tag.prefersLightText || tag.tone == .medium ? .white : Color(hex: 0x333333))
                    }
                }
                .overlay { ring(selection == tag) }
                Text(label ?? " ")
                    .font(.system(size: 8, weight: selection == tag ? .bold : .medium))
                    .foregroundStyle(selection == tag ? palette.primaryText : palette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(MiraPressStyle())
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.45).onEnded { _ in
            labelDraft = label ?? ""
            renaming = tag
        })
        .accessibilityLabel(label.map { "\(tag.title)、\($0)" } ?? tag.title)
        .accessibilityAddTraits(selection == tag ? .isSelected : [])
        .accessibilityAction(named: "ラベルを付ける") {
            labelDraft = label ?? ""
            renaming = tag
        }
        .accessibilityIdentifier("eventColor-\(tag.rawValue)")
    }

    private var noneOption: some View {
        Button { pick(nil) } label: {
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .strokeBorder(palette.secondaryText.opacity(0.5), style: StrokeStyle(lineWidth: 1.2, dash: [3, 2]))
                        .frame(width: 26, height: 26)
                    Image(systemName: "nosign")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(palette.secondaryText)
                }
                .overlay { ring(selection == nil) }
                Text("なし")
                    .font(.system(size: 8, weight: selection == nil ? .bold : .medium))
                    .foregroundStyle(palette.secondaryText)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(MiraPressStyle())
        .accessibilityLabel("色なし")
        .accessibilityAddTraits(selection == nil ? .isSelected : [])
    }

    @ViewBuilder
    private func ring(_ isSelected: Bool) -> some View {
        if isSelected {
            Circle()
                .strokeBorder(palette.primaryText.opacity(0.55), lineWidth: 2)
                .frame(width: 33, height: 33)
        }
    }

    private func pick(_ tag: EventColorTag?) {
        selection = tag
        onPick?(tag)
    }
}
