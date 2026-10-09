import Foundation

/// Mira's own color code, carried over from how she used Yahoo!カレンダー:
/// each color means a kind of plan. Margins keep their own kind-based colors
/// so "time for me" never blends into ordinary plans.
enum EventColorTag: String, Codable, CaseIterable, Identifiable, Sendable {
    case play
    case otaku
    case work
    case care
    case other
    case info
    case deadline
    case lottery
    case keiba
    case birthday

    var id: String { rawValue }

    /// The color's own name.
    var title: String {
        switch self {
        case .play: "水色"
        case .otaku: "うす水色"
        case .work: "薄赤"
        case .care: "うす黄緑"
        case .other: "うす黄色"
        case .info: "ピンク"
        case .deadline: "紫"
        case .lottery: "黒"
        case .keiba: "緑"
        case .birthday: "白"
        }
    }

    /// What the color is used for.
    var meaning: String {
        switch self {
        case .play: "遊び"
        case .otaku: "オタ活"
        case .work: "仕事"
        case .care: "通院・美容"
        case .other: "その他"
        case .info: "お知らせ"
        case .deadline: "試験・締切"
        case .lottery: "宝くじ"
        case .keiba: "競馬"
        case .birthday: "誕生日"
        }
    }

    /// Saturated tone for dots, bars and widgets.
    var swatchHex: UInt32 {
        switch self {
        case .play: 0x4FB3E8
        case .otaku: 0x9FD8F2
        case .work: 0xE88A8A
        case .care: 0xB5D97A
        case .other: 0xF0D867
        case .info: 0xF28CB8
        case .deadline: 0x9B7BD4
        case .lottery: 0x2B2B2B
        case .keiba: 0x3FA36B
        case .birthday: 0xFFFFFF
        }
    }

    /// Thin bars and widget accents, where pure white would vanish.
    var barHex: UInt32 {
        self == .birthday ? 0xCFCFCF : swatchHex
    }

    /// Light and white chips need an outline to stand off the page.
    var needsOutline: Bool { self == .birthday || self == .otaku }

    /// Picks a color from words in the title, in priority order, so a pasted
    /// or imported plan lands in the right color without asking.
    static func suggested(forTitle title: String) -> EventColorTag? {
        let rules: [(EventColorTag, [String])] = [
            (.birthday, ["誕生日", "バースデー", "birthday"]),
            (.lottery, ["宝くじ", "ロト", "ジャンボ", "ナンバーズ", "toto"]),
            (.keiba, ["競馬", "ダービー", "有馬", "天皇賞", "菊花賞", "桜花賞", "皐月賞", "秋華賞", "宝塚記念", "G1", "GⅠ", "馬券", "WIN5"]),
            (.deadline, ["試験", "テスト", "締切", "締め切り", "〆切", "提出", "期限", "検定", "レポート"]),
            (.care, ["美容院", "美容室", "歯医者", "歯科", "病院", "皮膚科", "眼科", "内科", "クリニック", "整体", "健診", "検診", "ネイル", "まつエク", "脱毛", "通院"]),
            (.work, ["仕事", "出勤", "バイト", "会議", "打ち合わせ", "研修", "出張", "面談", "シフト"]),
            (.info, ["お知らせ", "発売", "予約開始", "当選発表", "抽選", "受付開始", "配信開始", "公開日", "販売開始"]),
            (.otaku, ["ライブ", "コンサート", "舞台", "観劇", "イベント", "コラボ", "推し", "グッズ", "握手", "ファンミ", "声優", "アニメ", "オタ", "現場", "遠征"]),
            (.play, ["ご飯", "ごはん", "飲み", "ランチ", "ディナー", "遊", "カラオケ", "旅行", "カフェ", "デート", "映画", "ディズニー", "USJ", "買い物", "女子会", "BBQ", "焼肉", "おでかけ"])
        ]
        let lowered = title.lowercased()
        return rules.first { _, words in words.contains { lowered.contains($0.lowercased()) } }?.0
    }
}
