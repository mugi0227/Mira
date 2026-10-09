import SwiftUI

/// One-tap color row. `nil` means "no color" so plans can stay plain.
struct EventColorPicker: View {
    @Binding var selection: EventColorTag?
    let palette: MiraThemePalette
    var onPick: ((EventColorTag?) -> Void)?

    var body: some View {
        // Two calm rows keep every color visible without sideways scrolling.
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 5), spacing: 0) {
            noneButton
            ForEach(EventColorTag.allCases) { tag in
                dot(for: tag)
            }
        }
        .padding(.vertical, 2)
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("予定の色")
    }

    private var noneButton: some View {
        Button { pick(nil) } label: {
            ZStack {
                Circle()
                    .strokeBorder(palette.secondaryText.opacity(0.5), style: StrokeStyle(lineWidth: 1.2, dash: [3, 2]))
                    .frame(width: 30, height: 30)
                Image(systemName: "nosign")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
            }
            .overlay { selectionRing(isSelected: selection == nil) }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(MiraPressStyle())
        .accessibilityLabel("色なし")
        .accessibilityAddTraits(selection == nil ? .isSelected : [])
    }

    private func dot(for tag: EventColorTag) -> some View {
        Button { pick(tag) } label: {
            ZStack {
                Circle()
                    .fill(palette.swatch(for: tag))
                    .frame(width: 30, height: 30)
                if selection == tag {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.white)
                }
            }
            .overlay { selectionRing(isSelected: selection == tag) }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(MiraPressStyle())
        .accessibilityLabel(tag.title)
        .accessibilityAddTraits(selection == tag ? .isSelected : [])
        .accessibilityIdentifier("eventColor-\(tag.rawValue)")
    }

    @ViewBuilder
    private func selectionRing(isSelected: Bool) -> some View {
        if isSelected {
            Circle()
                .strokeBorder(palette.primaryText.opacity(0.55), lineWidth: 2)
                .frame(width: 38, height: 38)
        }
    }

    private func pick(_ tag: EventColorTag?) {
        selection = tag
        onPick?(tag)
    }
}
