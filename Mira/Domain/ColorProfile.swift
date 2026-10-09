import Foundation

/// A set of color labels plus word rules for coloring plans automatically.
/// Everyone starts with `.standard` (no rules; colors are learned from past
/// plans). Profiles tailored to one person are switched on by their account.
enum ColorProfile: String, Codable, Sendable {
    case standard
    case mira

    /// Labels applied when the profile turns on, without touching labels the
    /// person already wrote.
    var defaultLabels: [EventColorTag: String] {
        switch self {
        case .standard:
            return [:]
        case .mira:
            return [
                .sky: "遊び", .skyLight: "オタ活", .redLight: "仕事", .greenLight: "通院・美容",
                .yellowLight: "その他", .pink: "お知らせ", .purple: "試験・締切",
                .black: "宝くじ", .green: "競馬", .white: "誕生日"
            ]
        }
    }

    /// Color for imports when no rule or past plan matches.
    var fallbackColor: EventColorTag? {
        self == .mira ? .yellowLight : nil
    }

    func suggestedColor(forTitle title: String) -> EventColorTag? {
        let lowered = title.lowercased()
        return rules.first { _, words in words.contains { lowered.contains($0.lowercased()) } }?.0
    }

    private var rules: [(EventColorTag, [String])] {
        switch self {
        case .standard:
            return []
        case .mira:
            return [
                (.white, ["誕生日", "バースデー", "birthday"]),
                (.black, ["宝くじ", "ロト", "ジャンボ", "ナンバーズ", "toto"]),
                (.green, ["競馬", "ダービー", "有馬", "天皇賞", "菊花賞", "桜花賞", "皐月賞", "秋華賞", "宝塚記念", "G1", "GⅠ", "馬券", "WIN5"]),
                (.purple, ["試験", "テスト", "締切", "締め切り", "〆切", "提出", "期限", "検定", "レポート"]),
                (.greenLight, ["美容院", "美容室", "歯医者", "歯科", "病院", "皮膚科", "眼科", "内科", "クリニック", "整体", "健診", "検診", "ネイル", "まつエク", "脱毛", "通院"]),
                (.redLight, ["仕事", "出勤", "バイト", "会議", "打ち合わせ", "研修", "出張", "面談", "シフト"]),
                (.pink, ["お知らせ", "発売", "予約開始", "当選発表", "抽選", "受付開始", "配信開始", "公開日", "販売開始"]),
                (.skyLight, ["ライブ", "コンサート", "舞台", "観劇", "イベント", "コラボ", "推し", "グッズ", "握手", "ファンミ", "声優", "アニメ", "オタ", "現場", "遠征"]),
                (.sky, ["ご飯", "ごはん", "飲み", "ランチ", "ディナー", "遊", "カラオケ", "旅行", "カフェ", "デート", "映画", "ディズニー", "USJ", "買い物", "女子会", "BBQ", "焼肉", "おでかけ"])
            ]
        }
    }
}
