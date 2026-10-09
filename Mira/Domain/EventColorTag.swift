import Foundation

/// A color the user picks for a confirmed event. Margins keep their own
/// kind-based colors so "time for me" never blends into ordinary plans.
enum EventColorTag: String, Codable, CaseIterable, Identifiable, Sendable {
    case sakura
    case peach
    case lemon
    case mint
    case sky
    case lavender
    case cocoa
    case gray

    var id: String { rawValue }

    /// Saturated tone for dots, bars and widgets (light and dark alike).
    var swatchHex: UInt32 {
        switch self {
        case .sakura: 0xE8879F
        case .peach: 0xF0A072
        case .lemon: 0xE2C044
        case .mint: 0x62BE98
        case .sky: 0x68A4DA
        case .lavender: 0xA28CD6
        case .cocoa: 0xAE8868
        case .gray: 0x9C9FA6
        }
    }

    var title: String {
        switch self {
        case .sakura: "さくら"
        case .peach: "ピーチ"
        case .lemon: "レモン"
        case .mint: "ミント"
        case .sky: "そら"
        case .lavender: "ラベンダー"
        case .cocoa: "ココア"
        case .gray: "グレー"
        }
    }
}
