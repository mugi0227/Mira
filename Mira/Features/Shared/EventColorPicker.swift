import SwiftUI

/// One-tap color grid labeled with what each color means. `nil` keeps a
/// plan uncolored.
struct EventColorPicker: View {
    @Binding var selection: EventColorTag?
    let palette: MiraThemePalette
    var onPick: ((EventColorTag?) -> Void)?

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 6), spacing: 4) {
            ForEach(EventColorTag.allCases) { tag in
                option(tag)
            }
            noneOption
        }
        .padding(.vertical, 2)
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("予定の色")
    }

    private func option(_ tag: EventColorTag) -> some View {
        Button { pick(tag) } label: {
            VStack(spacing: 3) {
                ZStack {
                    Circle()
                        .fill(palette.swatch(for: tag))
                        .overlay {
                            if tag.needsOutline {
                                Circle().strokeBorder(palette.primaryText.opacity(0.25), lineWidth: 1)
                            }
                        }
                        .frame(width: 28, height: 28)
                    if selection == tag {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(tag == .birthday || tag == .otaku || tag == .other ? Color(hex: 0x333333) : .white)
                    }
                }
                .overlay { ring(selection == tag) }
                Text(tag.meaning)
                    .font(.system(size: 9, weight: selection == tag ? .bold : .medium))
                    .foregroundStyle(selection == tag ? palette.primaryText : palette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(MiraPressStyle())
        .accessibilityLabel("\(tag.title)、\(tag.meaning)")
        .accessibilityAddTraits(selection == tag ? .isSelected : [])
        .accessibilityIdentifier("eventColor-\(tag.rawValue)")
    }

    private var noneOption: some View {
        Button { pick(nil) } label: {
            VStack(spacing: 3) {
                ZStack {
                    Circle()
                        .strokeBorder(palette.secondaryText.opacity(0.5), style: StrokeStyle(lineWidth: 1.2, dash: [3, 2]))
                        .frame(width: 28, height: 28)
                    Image(systemName: "nosign")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.secondaryText)
                }
                .overlay { ring(selection == nil) }
                Text("なし")
                    .font(.system(size: 9, weight: selection == nil ? .bold : .medium))
                    .foregroundStyle(palette.secondaryText)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
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
                .frame(width: 36, height: 36)
        }
    }

    private func pick(_ tag: EventColorTag?) {
        selection = tag
        onPick?(tag)
    }
}
