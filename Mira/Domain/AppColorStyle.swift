import Foundation

enum AppColorStyle: String, Codable, CaseIterable, Identifiable {
    case blue
    case sage
    case rose
    case lavender

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blue: "ブルー＆ホワイト"
        case .sage: "アイボリー＆セージ"
        case .rose: "ローズ"
        case .lavender: "ラベンダー"
        }
    }
}
