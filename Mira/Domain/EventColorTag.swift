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
