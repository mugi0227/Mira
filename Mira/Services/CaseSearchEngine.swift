import Foundation

struct CaseSearchEngine: Sendable {
    private let calendar: Calendar

    init(calendar: Calendar = .mira) {
        self.calendar = calendar
    }

    func search(
        query: String,
        includePast: Bool,
        now: Date,
        cases: [ConversationCaseEntity],
        items: [CalendarItemSnapshot],
        adjustments: [AdjustmentEntity],
        invitations: [PendingInvitationEntity],
        kindFilter: ConversationCaseKind? = nil,
        limit: Int = 20
    ) -> [ContextSearchResult] {
        let normalizedQuery = normalize(query)
        let compactQuery = compact(normalizedQuery)
        let tokens = searchTokens(from: normalizedQuery)
        var results: [ContextSearchResult] = []

        for conversationCase in cases where conversationCase.status != .archived {
            let state = conversationCase.state
            let kind = conversationCase.kind
            guard kindFilter == nil || kindFilter == kind else { continue }

            let date = state.dateRangeStart
            let isPast = date.map { $0 < calendar.startOfDay(for: now) } ?? false
            guard includePast || !isPast else { continue }

            let score = score(
                query: normalizedQuery,
                compactQuery: compactQuery,
                tokens: tokens,
                title: conversationCase.title,
                person: state.person,
                date: date,
                statusBoost: conversationCase.status == .active || conversationCase.status == .waiting ? 18 : 4,
                now: now
            )
            guard normalizedQuery.isEmpty || score > 0 else { continue }

            results.append(ContextSearchResult(
                id: conversationCase.id,
                kind: kind,
                title: conversationCase.title,
                subtitle: subtitle(for: conversationCase, date: date),
                startDate: date,
                endDate: state.dateRangeEnd,
                relatedCaseID: conversationCase.id,
                relatedItemID: state.relatedItemID,
                relatedAdjustmentID: state.relatedAdjustmentID,
                relatedInvitationID: state.relatedInvitationID,
                score: score,
                isPast: isPast
            ))
        }

        for item in items where item.kind != .margin && item.kind != .birthday {
            let isPast = item.endDate < now
            guard includePast || !isPast else { continue }
            guard kindFilter == nil || kindFilter == .confirmedEvent else { continue }
            if let caseID = item.conversationCaseID,
               results.contains(where: { $0.relatedCaseID == caseID }) {
                continue
            }

            let score = score(
                query: normalizedQuery,
                compactQuery: compactQuery,
                tokens: tokens,
                title: item.title,
                person: nil,
                date: item.startDate,
                statusBoost: 10,
                now: now
            )
            guard normalizedQuery.isEmpty || score > 0 else { continue }

            results.append(ContextSearchResult(
                id: item.id,
                kind: .confirmedEvent,
                title: item.title,
                subtitle: "\(item.startDate.japaneseShortDate)  \(item.timeDescription)",
                startDate: item.startDate,
                endDate: item.endDate,
                relatedCaseID: item.conversationCaseID,
                relatedItemID: item.id,
                relatedAdjustmentID: nil,
                relatedInvitationID: nil,
                score: score,
                isPast: isPast
            ))
        }

        for adjustment in adjustments where adjustment.status == .draft || adjustment.status == .waiting {
            guard kindFilter == nil || kindFilter == .adjustment else { continue }
            if let caseID = adjustment.conversationCaseID,
               results.contains(where: { $0.relatedCaseID == caseID }) {
                continue
            }
            let first = adjustment.candidates.map(\.startDate).min()
            let isPast = first.map { $0 < calendar.startOfDay(for: now) } ?? false
            guard includePast || !isPast else { continue }
            let score = score(
                query: normalizedQuery,
                compactQuery: compactQuery,
                tokens: tokens,
                title: adjustment.title,
                person: adjustment.contactName,
                date: first,
                statusBoost: 20,
                now: now
            )
            guard normalizedQuery.isEmpty || score > 0 else { continue }
            results.append(ContextSearchResult(
                id: adjustment.id,
                kind: .adjustment,
                title: adjustment.title,
                subtitle: adjustment.status == .waiting ? "返事待ち・候補\(adjustment.candidates.count)件" : "候補を編集中",
                startDate: first,
                endDate: adjustment.candidates.map(\.endDate).max(),
                relatedCaseID: adjustment.conversationCaseID,
                relatedItemID: nil,
                relatedAdjustmentID: adjustment.id,
                relatedInvitationID: nil,
                score: score,
                isPast: isPast
            ))
        }

        for invitation in invitations where invitation.status == .considering || invitation.status == .adjustment {
            guard kindFilter == nil || kindFilter == .invitation else { continue }
            if let caseID = invitation.conversationCaseID,
               results.contains(where: { $0.relatedCaseID == caseID }) {
                continue
            }
            let first = invitation.candidates.map(\.startDate).min()
            let isPast = first.map { $0 < calendar.startOfDay(for: now) } ?? false
            guard includePast || !isPast else { continue }
            let score = score(
                query: normalizedQuery,
                compactQuery: compactQuery,
                tokens: tokens,
                title: invitation.title,
                person: invitation.contactName,
                date: first,
                statusBoost: 20,
                now: now
            )
            guard normalizedQuery.isEmpty || score > 0 else { continue }
            results.append(ContextSearchResult(
                id: invitation.id,
                kind: .invitation,
                title: invitation.title,
                subtitle: "検討中\(first.map { "・\($0.japaneseShortDate)" } ?? "")",
                startDate: first,
                endDate: invitation.candidates.map(\.endDate).max(),
                relatedCaseID: invitation.conversationCaseID,
                relatedItemID: nil,
                relatedAdjustmentID: nil,
                relatedInvitationID: invitation.id,
                score: score,
                isPast: isPast
            ))
        }

        return results
            .sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                switch ($0.startDate, $1.startDate) {
                case let (lhs?, rhs?): return lhs < rhs
                case (.some, .none): return true
                case (.none, .some): return false
                default: return $0.title < $1.title
                }
            }
            .prefix(max(1, limit))
            .map { $0 }
    }

    func automaticCandidates(
        for input: String,
        now: Date,
        cases: [ConversationCaseEntity],
        items: [CalendarItemSnapshot],
        adjustments: [AdjustmentEntity],
        invitations: [PendingInvitationEntity],
        limit: Int = 5
    ) -> [ContextSearchResult] {
        search(
            query: input,
            includePast: false,
            now: now,
            cases: cases,
            items: items,
            adjustments: adjustments,
            invitations: invitations,
            limit: limit
        )
    }

    private func score(
        query: String,
        compactQuery: String,
        tokens: [String],
        title: String,
        person: String?,
        date: Date?,
        statusBoost: Double,
        now: Date
    ) -> Double {
        let normalizedTitle = normalize(title)
        let compactTitle = compact(normalizedTitle)
        let normalizedPerson = normalize(person ?? "")
        let compactPerson = compact(normalizedPerson)
        var value = statusBoost
        var matched = false

        if query.isEmpty {
            value += recencyScore(date: date, now: now)
            return value
        }

        if normalizedTitle == query || compactTitle == compactQuery {
            value += 120
            matched = true
        }
        if normalizedTitle.contains(query) || query.contains(normalizedTitle) || compactQuery.contains(compactTitle) {
            value += 75
            matched = true
        }
        if !compactPerson.isEmpty, compactQuery.contains(compactPerson) {
            value += 55
            matched = true
        }

        for token in tokens where token.count >= 2 {
            if normalizedTitle.contains(token) {
                value += 26
                matched = true
            }
            if normalizedPerson.contains(token) {
                value += 18
                matched = true
            }
        }

        let titleMatches = matchingFragments(from: compactTitle, in: compactQuery)
        if let longest = titleMatches.max() {
            value += Double(longest * 14)
            matched = true
        }
        let personMatches = matchingFragments(from: compactPerson, in: compactQuery)
        if let longest = personMatches.max() {
            value += Double(longest * 9)
            matched = true
        }

        guard matched else { return 0 }
        value += recencyScore(date: date, now: now)
        return value
    }

    private func matchingFragments(from source: String, in query: String) -> [Int] {
        guard source.count >= 2, query.count >= 2 else { return [] }
        let characters = Array(source)
        let maximumLength = min(6, characters.count)
        var lengths: [Int] = []
        for length in stride(from: maximumLength, through: 2, by: -1) {
            guard characters.count >= length else { continue }
            for start in 0...(characters.count - length) {
                let fragment = String(characters[start..<(start + length)])
                guard !isNoisyFragment(fragment) else { continue }
                if query.contains(fragment) {
                    lengths.append(length)
                    break
                }
            }
            if !lengths.isEmpty { break }
        }
        return lengths
    }

    private func isNoisyFragment(_ fragment: String) -> Bool {
        let noise = ["友達", "予定", "調整", "一緒", "さんと", "との", "の件", "これ", "それ"]
        return noise.contains(fragment)
    }

    private func recencyScore(date: Date?, now: Date) -> Double {
        guard let date else { return 2 }
        let days = abs(calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 365)
        return max(0, 24 - Double(days) * 0.4)
    }

    private func normalize(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .widthInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ja_JP"))
            .replacingOccurrences(of: "　", with: " ")
            .replacingOccurrences(of: "[^\\p{L}\\p{N}]", with: " ", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .lowercased()
    }

    private func compact(_ text: String) -> String {
        text.replacingOccurrences(of: " ", with: "")
    }

    private func searchTokens(from normalized: String) -> [String] {
        let stopWords: Set<String> = [
            "の", "件", "やつ", "こと", "さ", "さー", "について", "これ", "あれ", "それ",
            "夜", "昼", "朝", "なし", "無理", "お願い", "予定", "変更", "したい", "なった"
        ]
        return normalized.split(separator: " ").map(String.init).filter { !stopWords.contains($0) }
    }

    private func subtitle(for conversationCase: ConversationCaseEntity, date: Date?) -> String {
        let status: String
        switch conversationCase.status {
        case .active: status = "進行中"
        case .waiting: status = "返事待ち"
        case .confirmed: status = "確定"
        case .completed: status = "完了"
        case .archived: status = "アーカイブ"
        }
        if let date { return "\(status)・\(date.japaneseShortDate)" }
        return status
    }
}
