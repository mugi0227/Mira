import SwiftUI

enum ImportStep {
    case intro
    case source
    case analyzing
    case review
    case duplicates
    case completed
}

enum LegacySource: String, CaseIterable, Identifiable {
    case yahoo
    case line
    case other

    var id: String { rawValue }
    var title: String {
        switch self {
        case .yahoo: "Yahoo!カレンダー"
        case .line: "LINEカレンダー"
        case .other: "その他のカレンダー"
        }
    }
    var subtitle: String {
        switch self {
        case .yahoo: "長年の誕生日や繰り返し予定を救出"
        case .line: "移行後の予定をまとめて確認"
        case .other: "PDFや月表示のスクリーンショットから"
        }
    }
    var symbol: String {
        switch self {
        case .yahoo: "calendar"
        case .line: "message.fill"
        case .other: "square.grid.2x2.fill"
        }
    }
}

enum LegacyImportCategory: String, CaseIterable, Identifiable {
    case future
    case annual
    case recurring

    var id: String { rawValue }
    var title: String {
        switch self {
        case .future: "これからの予定"
        case .annual: "誕生日・記念日"
        case .recurring: "繰り返し予定"
        }
    }
    var symbol: String {
        switch self {
        case .future: "calendar.badge.clock"
        case .annual: "gift.fill"
        case .recurring: "repeat"
        }
    }
}

struct LegacyImportItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let category: LegacyImportCategory
}

enum LegacyImportSample {
    static let items = [
        LegacyImportItem(title: "美容院", detail: "9月14日 11:00", category: .future),
        LegacyImportItem(title: "友達と旅行", detail: "10月3日〜4日", category: .future),
        LegacyImportItem(title: "ライブ", detail: "11月21日 16:00", category: .future),
        LegacyImportItem(title: "Aさん誕生日", detail: "毎年 3月7日", category: .annual),
        LegacyImportItem(title: "Bさん誕生日", detail: "毎年 5月21日", category: .annual),
        LegacyImportItem(title: "記念日", detail: "毎年 8月10日", category: .annual),
        LegacyImportItem(title: "定例会", detail: "毎月 第1日曜日", category: .recurring),
        LegacyImportItem(title: "レッスン", detail: "毎週 水曜日", category: .recurring)
    ]
}

struct ImportFeatureRow: View {
    let symbol: String
    let text: String
    let palette: MiraThemePalette

    var body: some View {
        HStack(spacing: MiraSpacing.sm) {
            Image(systemName: symbol)
                .foregroundStyle(palette.accent)
                .frame(width: 28)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(palette.primaryText)
        }
        .frame(minHeight: 40)
    }
}
