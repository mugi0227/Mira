import Foundation

/// A plan color, like Yahoo!カレンダー's: seven hues in three tones plus
/// white, gray and black. Colors carry no fixed meaning; each person names
/// the ones they use (long-press in the picker). Margins keep their own
/// kind-based colors so "time for me" never blends into ordinary plans.
enum EventColorTag: String, Codable, CaseIterable, Identifiable, Sendable {
    // Light row
    case pinkLight, redLight, orangeLight, yellowLight, greenLight, skyLight, purpleLight
    // Medium row
    case pink, red, orange, yellow, green, sky, purple
    // Deep row
    case pinkDeep, redDeep, orangeDeep, yellowDeep, greenDeep, skyDeep, purpleDeep
    // Neutrals
    case white, gray, black

    enum Tone: Sendable { case light, medium, deep, neutral }

    var id: String { rawValue }

    var tone: Tone {
        switch self {
        case .pinkLight, .redLight, .orangeLight, .yellowLight, .greenLight, .skyLight, .purpleLight: .light
        case .pink, .red, .orange, .yellow, .green, .sky, .purple: .medium
        case .pinkDeep, .redDeep, .orangeDeep, .yellowDeep, .greenDeep, .skyDeep, .purpleDeep: .deep
        case .white, .gray, .black: .neutral
        }
    }

    /// The color's own name, used when it has no label.
    var title: String {
        let hue: String
        switch self {
        case .pinkLight, .pink, .pinkDeep: hue = "ピンク"
        case .redLight, .red, .redDeep: hue = "赤"
        case .orangeLight, .orange, .orangeDeep: hue = "オレンジ"
        case .yellowLight, .yellow, .yellowDeep: hue = "黄色"
        case .greenLight, .green, .greenDeep: hue = "緑"
        case .skyLight, .sky, .skyDeep: hue = "水色"
        case .purpleLight, .purple, .purpleDeep: hue = "紫"
        case .white: return "白"
        case .gray: return "グレー"
        case .black: return "黒"
        }
        switch tone {
        case .light: return "うすい" + hue
        case .deep: return "こい" + hue
        default: return hue
        }
    }

    var swatchHex: UInt32 {
        switch self {
        case .pinkLight: 0xF9D2E2
        case .redLight: 0xF6C9C9
        case .orangeLight: 0xFBDDC3
        case .yellowLight: 0xFBF0B8
        case .greenLight: 0xD6EDC4
        case .skyLight: 0xCDEBF8
        case .purpleLight: 0xE1D6F2
        case .pink: 0xF28CB8
        case .red: 0xE57373
        case .orange: 0xF4A261
        case .yellow: 0xF2D04A
        case .green: 0x7CC47F
        case .sky: 0x5DB8E8
        case .purple: 0xA387D8
        case .pinkDeep: 0xC2185B
        case .redDeep: 0xC62828
        case .orangeDeep: 0xE06A10
        case .yellowDeep: 0xC9A100
        case .greenDeep: 0x2E7D32
        case .skyDeep: 0x1E78B4
        case .purpleDeep: 0x6A3FB0
        case .white: 0xFFFFFF
        case .gray: 0x9E9E9E
        case .black: 0x2B2B2B
        }
    }

    /// Thin bars and widget accents: light tones and white would vanish, so
    /// they borrow the medium tone of their hue.
    var barHex: UInt32 {
        switch self {
        case .pinkLight: EventColorTag.pink.swatchHex
        case .redLight: EventColorTag.red.swatchHex
        case .orangeLight: EventColorTag.orange.swatchHex
        case .yellowLight: EventColorTag.yellow.swatchHex
        case .greenLight: EventColorTag.green.swatchHex
        case .skyLight: EventColorTag.sky.swatchHex
        case .purpleLight: EventColorTag.purple.swatchHex
        case .white: 0xCFCFCF
        default: swatchHex
        }
    }

    /// Deep tones and black are dark enough to need white text.
    var prefersLightText: Bool { tone == .deep || self == .black }

    var needsOutline: Bool { self == .white }
}
