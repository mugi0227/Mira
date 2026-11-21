import SwiftUI

struct ColorStylePickerView: View {
    @Environment(MiraStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var palette: MiraThemePalette {
        MiraThemePalette(kind: store.theme, colorScheme: colorScheme, colorStyle: store.colorStyle)
    }

    var body: some View {
        List {
            Section {
                ForEach(AppColorStyle.allCases) { style in
                    let preview = MiraThemePalette(kind: store.theme, colorScheme: colorScheme, colorStyle: style)
                    Button {
                        withAnimation(MiraMotion.selection(reduceMotion: reduceMotion)) {
                            store.setColorStyle(style)
                        }
                    } label: {
                        HStack(spacing: MiraSpacing.md) {
                            HStack(spacing: -8) {
                                ForEach(0..<3) { index in
                                    Circle()
                                        .fill([preview.background, preview.accentSoft, preview.accent][index])
                                        .frame(width: 28, height: 28)
                                        .overlay(Circle().strokeBorder(preview.cardBorder, lineWidth: 1))
                                }
                            }
                            Text(style.title)
                                .font(.headline)
                            Spacer(minLength: 0)
                            if store.colorStyle == style {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(palette.accent)
                            }
                        }
                        .foregroundStyle(palette.primaryText)
                        .frame(minHeight: 56)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(MiraPressStyle())
                    .accessibilityElement(children: .ignore)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(style.title)
                    .accessibilityValue(store.colorStyle == style ? "選択中" : "")
                    .accessibilityIdentifier("appColor-\(style.rawValue)")
                    .listRowBackground(palette.surface)
                }
            } footer: {
                Text("スキンと組み合わせて選べます。予定の色ラベルは変更しません。")
            }
        }
        .scrollContentBackground(.hidden)
        .miraFormStyle(palette)
        .miraScreenBackground(palette)
        .navigationTitle("アプリの色")
        .navigationBarTitleDisplayMode(.inline)
    }
}
