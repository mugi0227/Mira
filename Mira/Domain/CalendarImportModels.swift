import Foundation

/// One plan read off a screenshot, waiting for the person to keep or drop it.
struct ImportCandidate: Identifiable, Hashable, Sendable {
    var id = UUID()
    var title: String
    var start: Date
    var end: Date
    var isAllDay: Bool
    var colorTag: EventColorTag?
    var confidence: Double
    var sourceIndex: Int
    var isSelected = true
    var duplicateOf: String?

    /// Low confidence or odd shapes are flagged rather than silently trusted.
    var needsReview: Bool {
        confidence < 0.7 || title.count <= 1 || end <= start
    }
}

/// The JSON shape Gemini is asked to return.
struct ExtractedCalendarPage: Codable, Sendable {
    struct Event: Codable, Sendable {
        var title: String
        var date: String
        var endDate: String?
        var startTime: String?
        var endTime: String?
        var allDay: Bool
        var confidence: Double?
    }

    var events: [Event]
}

enum ImportCandidateBuilder {
    /// Turns extracted text fields into dated candidates on Mira's calendar.
    static func candidates(from page: ExtractedCalendarPage, sourceIndex: Int) -> [ImportCandidate] {
        let day = DateFormatter.mira("yyyy-MM-dd", locale: Locale(identifier: "en_US_POSIX"))
        let calendar = Calendar.mira
        return page.events.compactMap { event in
            let title = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, let date = day.date(from: event.date.trimmingCharacters(in: .whitespaces)) else { return nil }
            let lastDay = event.endDate.flatMap { day.date(from: $0.trimmingCharacters(in: .whitespaces)) }
            let start: Date
            let end: Date
            let startTime = event.startTime.flatMap(minutes(from:))
            if event.allDay || startTime == nil {
                start = calendar.startOfDay(for: date)
                let finalDay = max(lastDay ?? date, date)
                end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: finalDay)) ?? start.addingTimeInterval(86_400)
            } else {
                start = date.addingTimeInterval(TimeInterval((startTime ?? 0) * 60))
                if let endTime = event.endTime.flatMap(minutes(from:)) {
                    let endBase = calendar.startOfDay(for: lastDay ?? date)
                    var value = endBase.addingTimeInterval(TimeInterval(endTime * 60))
                    if value <= start { value = value.addingTimeInterval(86_400) }
                    end = value
                } else {
                    end = start.addingTimeInterval(3600)
                }
            }
            return ImportCandidate(
                title: title,
                start: start,
                end: end,
                isAllDay: event.allDay || startTime == nil,
                colorTag: EventColorTag.suggested(forTitle: title) ?? .other,
                confidence: min(max(event.confidence ?? 0.8, 0), 1),
                sourceIndex: sourceIndex
            )
        }
    }

    /// "9:00", "09:00", "9時" → minutes after midnight.
    static func minutes(from text: String) -> Int? {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "時", with: ":")
            .replacingOccurrences(of: "分", with: "")
            .replacingOccurrences(of: "：", with: ":")
        guard !cleaned.isEmpty else { return nil }
        let parts = cleaned.split(separator: ":", omittingEmptySubsequences: false)
        guard let hour = Int(parts[0]), (0...24).contains(hour) else { return nil }
        let minute = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
        guard (0...59).contains(minute) else { return nil }
        return hour * 60 + minute
    }

    /// Same day and a matching title (either contains the other) counts as
    /// already in the calendar; overlapping screenshots also repeat plans.
    static func markDuplicates(_ candidates: [ImportCandidate], existing: [CalendarItemSnapshot]) -> [ImportCandidate] {
        var seen: [(Date, String)] = []
        return candidates.map { candidate in
            var value = candidate
            let calendar = Calendar.mira
            let key = normalized(candidate.title)
            if let match = existing.first(where: {
                calendar.isDate($0.startDate, inSameDayAs: candidate.start) && similar(normalized($0.title), key)
            }) {
                value.duplicateOf = match.title
                value.isSelected = false
            } else if seen.contains(where: { calendar.isDate($0.0, inSameDayAs: candidate.start) && similar($0.1, key) }) {
                value.duplicateOf = candidate.title
                value.isSelected = false
            }
            seen.append((candidate.start, key))
            return value
        }
    }

    private static func normalized(_ text: String) -> String {
        text.lowercased().filter { !$0.isWhitespace && $0 != "…" && $0 != "." }
    }

    private static func similar(_ lhs: String, _ rhs: String) -> Bool {
        guard !lhs.isEmpty, !rhs.isEmpty else { return false }
        return lhs == rhs || lhs.contains(rhs) || rhs.contains(lhs)
    }
}
