import Foundation

struct LoadRule: Hashable, Sendable {
    var keyword: String
    var loadClass: LoadClass
}

struct LoadEngine: Sendable {
    private let calendar: Calendar

    init(calendar: Calendar = .mira) {
        self.calendar = calendar
    }

    func evaluate(
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        semantic: EventSemanticClassification? = nil,
        explicitRules: [LoadRule] = []
    ) -> LoadEvaluation {
        let normalized = title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        if let rule = explicitRules.first(where: { normalized.localizedCaseInsensitiveContains($0.keyword) }) {
            let buffers = buffers(for: rule.loadClass, category: "user-rule", outside: true)
            return LoadEvaluation(
                loadClass: rule.loadClass,
                score: rule.loadClass.score,
                reason: "あなたが明示的に設定した負荷ルール",
                category: "user-rule",
                likelyOutsideHome: true,
                bufferBeforeMinutes: buffers.before,
                bufferAfterMinutes: buffers.after,
                source: "user"
            )
        }

        let ruleClassification = classifyByRules(normalized)
        let baseClass = semantic?.estimatedLoad ?? ruleClassification.loadClass
        let category = semantic?.category ?? ruleClassification.category
        let outside = semantic?.likelyOutsideHome ?? ruleClassification.outside

        var score = baseClass.score
        var reasons: [String] = [semantic?.shortReason ?? ruleClassification.reason]

        let weekday = calendar.component(.weekday, from: startDate)
        let hour = calendar.component(.hour, from: startDate)
        if (2...6).contains(weekday), hour >= 18, outside {
            score += 10
            reasons.append("平日夜の外出")
        }

        let actualHours = max(0, endDate.timeIntervalSince(startDate) / 3600)
        if !isAllDay && actualHours >= 6 {
            score += 12
            reasons.append("長時間の予定")
        } else if !isAllDay && actualHours <= 1, baseClass <= .normal {
            score -= 7
        }

        // An all-day flag is weak evidence: titles such as birthdays and salon visits
        // must not become heavy solely because users registered them as all-day.
        if isAllDay && ["travel", "outdoor", "event"].contains(category) {
            score += 8
        }

        score = min(100, max(0, score))
        let finalClass = LoadClass.from(score: score)
        let buffers = buffers(for: finalClass, category: category, outside: outside)

        return LoadEvaluation(
            loadClass: finalClass,
            score: score,
            reason: reasons.filter { !$0.isEmpty }.joined(separator: "・"),
            category: category,
            likelyOutsideHome: outside,
            bufferBeforeMinutes: buffers.before,
            bufferAfterMinutes: buffers.after,
            source: semantic?.source ?? "rules"
        )
    }

    private func classifyByRules(_ title: String) -> (loadClass: LoadClass, category: String, outside: Bool, reason: String) {
        let matches: [(keywords: [String], load: LoadClass, category: String, outside: Bool, reason: String)] = [
            (["誕生日", "birthday", "記念日"], .light, "birthday", false, "表示中心の記念日"),
            (["富士", "登山", "旅行", "キャンプ", "遠征"], .veryHeavy, "travel", true, "一日規模の遠出"),
            (["フェス", "ライブ", "結婚式", "イベント"], .heavy, "event", true, "長時間のイベント"),
            (["飲み", "飲み会", "宴会", "送別会", "歓迎会"], .heavy, "social", true, "外出と回復時間が必要な予定"),
            (["美容院", "病院", "歯医者", "映画", "ランチ", "ご飯", "カフェ", "買い物"], .normal, "outing", true, "移動を伴う外出"),
            (["オンライン", "電話", "通話", "受取"], .light, "short", false, "短時間で完了しやすい予定"),
            (["読書", "映像", "映画鑑賞", "だらだら", "休息", "家"], .light, "home", false, "自宅で過ごす低負荷の時間")
        ]

        for match in matches where match.keywords.contains(where: { title.localizedCaseInsensitiveContains($0) }) {
            return (match.load, match.category, match.outside, match.reason)
        }
        return (.normal, "other", true, "一般的な外出予定として推定")
    }

    func correctedBuffers(title: String, load: LoadClass) -> (before: Int, after: Int) {
        let classification = classifyByRules(title)
        return buffers(for: load, category: "user-rule", outside: classification.outside)
    }

    private func buffers(for loadClass: LoadClass, category: String, outside: Bool) -> (before: Int, after: Int) {
        guard outside else { return (0, loadClass == .light ? 0 : 15) }
        switch category {
        case "travel", "outdoor": return (90, 120)
        case "social": return (45, 120)
        case "event": return (60, 90)
        case "outing": return (30, 45)
        default:
            switch loadClass {
            case .light: return (15, 15)
            case .normal: return (30, 45)
            case .heavy: return (45, 90)
            case .veryHeavy: return (90, 120)
            }
        }
    }
}
