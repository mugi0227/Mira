import SwiftUI

/// Names for each color, the same labels the picker shows under its dots.
struct ColorLabelSettingsView: View {
    @Environment(MiraStore.self) private var store
    let palette: MiraThemePalette

    var body: some View {
        Form {
            Section {
                ForEach(EventColorTag.allCases) { tag in
                    HStack(spacing: MiraSpacing.sm) {
                        Circle()
                            .fill(palette.swatch(for: tag))
                            .overlay { Circle().strokeBorder(palette.primaryText.opacity(0.18), lineWidth: 1) }
                            .frame(width: 24, height: 24)
                        Text(tag.title)
                            .font(.subheadline)
                            .foregroundStyle(palette.secondaryText)
                            .frame(width: 96, alignment: .leading)
                        TextField("ラベルなし", text: Binding(
                            get: { store.label(for: tag) ?? "" },
                            set: { store.setLabel($0, for: tag) }
                        ))
                        .font(.subheadline.weight(.semibold))
                    }
                    .frame(minHeight: 40)
                }
            } footer: {
                Text("予定の色を選ぶときに、丸を長押ししても付けられます。似た名前の予定には、前に使った色を自動で付けます。")
            }
            .listRowBackground(palette.surface)
        }
        .scrollContentBackground(.hidden)
        .miraScreenBackground(palette)
        .navigationTitle("色のラベル")
        .navigationBarTitleDisplayMode(.inline)
    }
}
