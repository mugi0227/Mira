import SwiftUI

extension CalendarDisplayOptions.TextWeight {
    var fontWeight: Font.Weight {
        switch self {
        case .ultraLight: .ultraLight
        case .light: .light
        case .standard: .regular
        case .bold: .bold
        }
    }
}

struct CalendarLabelAppearance {
    let options: CalendarDisplayOptions
    let palette: MiraThemePalette
    let tag: EventColorTag?
    let isTimed: Bool

    var textOnly: Bool { isTimed && options.distinguishesTimedEvents }

    var foreground: Color {
        if textOnly || options.labelStyle == .color { return tag.map(coloredText(for:)) ?? palette.primaryText }
        if options.labelStyle == .ink { return palette.primaryText }
        return tag.map { $0.prefersLightText && $0 != .yellowDeep && $0 != .orangeDeep ? .white : Color(hex: 0x242424) } ?? palette.primaryText
    }

    var background: Color {
        if textOnly { return .clear }
        guard let tag else { return palette.elevatedSurface }
        return options.labelStyle == .vivid ? palette.swatch(for: tag) : palette.swatch(for: tag).opacity(0.22)
    }

    private func coloredText(for tag: EventColorTag) -> Color {
        if palette.isDark && tag != .black { return palette.swatch(for: tag.lightVariantForText) }
        switch tag {
        case .pinkLight, .pink, .pinkDeep: return palette.swatch(for: .pinkDeep)
        case .redLight, .red, .redDeep: return palette.swatch(for: .redDeep)
        case .orangeLight, .orange, .orangeDeep: return Color(hex: 0x9F4415)
        case .yellowLight, .yellow, .yellowDeep: return Color(hex: 0x765B00)
        case .greenLight, .green, .greenDeep: return palette.swatch(for: .greenDeep)
        case .skyLight, .sky, .skyDeep: return Color(hex: 0x135B8E)
        case .purpleLight, .purple, .purpleDeep: return palette.swatch(for: .purpleDeep)
        case .white, .gray, .black: return palette.primaryText
        }
    }
}

private extension EventColorTag {
    var lightVariantForText: Self {
        switch self {
        case .pinkLight, .pink, .pinkDeep: .pinkLight
        case .redLight, .red, .redDeep: .redLight
        case .orangeLight, .orange, .orangeDeep: .orangeLight
        case .yellowLight, .yellow, .yellowDeep: .yellowLight
        case .greenLight, .green, .greenDeep: .greenLight
        case .skyLight, .sky, .skyDeep: .skyLight
        case .purpleLight, .purple, .purpleDeep: .purpleLight
        case .white, .gray, .black: .white
        }
    }
}
