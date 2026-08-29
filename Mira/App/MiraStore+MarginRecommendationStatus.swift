import Foundation

struct MarginTargetChange: Identifiable, Hashable, Sendable {
    var kind: MarginKind
    var current: Int
    var recommended: Int

    var id: MarginKind { kind }
    var delta: Int { recommended - current }
}

@MainActor
extension MiraStore {
    var marginTargetChanges: [MarginTargetChange] {
        guard let recommendation = currentMarginRecommendation,
              Calendar.mira.isDate(recommendation.month, equalTo: selectedMonth, toGranularity: .month) else {
            return []
        }
        let currentByKind = Dictionary(uniqueKeysWithValues: currentMonthGoals.map { ($0.kind, $0.targetCount) })
        return recommendation.targets.compactMap { kind, recommended in
            guard kind != .importantPeople else { return nil }
            let current = currentByKind[kind] ?? 0
            guard current != recommended else { return nil }
            return MarginTargetChange(kind: kind, current: current, recommended: recommended)
        }
        .sorted {
            if abs($0.delta) != abs($1.delta) { return abs($0.delta) > abs($1.delta) }
            return $0.kind.defaultPriority > $1.kind.defaultPriority
        }
    }

    var hasMarginTargetRecommendationChange: Bool {
        !marginTargetChanges.isEmpty
    }

    var marginTargetChangeMessage: String {
        let increases = marginTargetChanges.filter { $0.delta > 0 }
        if let first = increases.first {
            let more = first.delta
            return "今月の負荷なら、\(first.kind.title)をあと\(more)枠増やすと楽になりそう。"
        }
        if let first = marginTargetChanges.first {
            return "今月は少し軽くなったので、\(first.kind.title)の目標を\(first.recommended)枠へ見直せます。"
        }
        return "今月の余白量は今のままでよさそうです。"
    }
}
