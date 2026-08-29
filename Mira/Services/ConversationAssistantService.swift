import Foundation

protocol ConversationInterpreting: Sendable {
    func interpret(
        text: String,
        now: Date,
        pinnedContext: ContextSearchResult?,
        searchCandidates: [ContextSearchResult],
        recentTurns: [ConversationTurnSnapshot]
    ) async -> ConversationInterpretation
}

protocol DeclineDraftGenerating: Sendable {
    func generate(
        title: String,
        person: String?,
        previous: String?,
        softer: Bool,
        audience: DeclineAudience,
        generationIndex: Int
    ) async -> DeclineDraft
}

struct HybridConversationInterpreter: ConversationInterpreting {
    private let fallback = RuleBasedConversationInterpreter()

    func interpret(
        text: String,
        now: Date,
        pinnedContext: ContextSearchResult?,
        searchCandidates: [ContextSearchResult],
        recentTurns: [ConversationTurnSnapshot]
    ) async -> ConversationInterpretation {
        let deterministicContext = resolvedContext(pinned: pinnedContext, candidates: searchCandidates)

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), FoundationModelConversationInterpreter.isAvailable,
           let interpreted = await FoundationModelConversationInterpreter().interpretIfAvailable(
                text: text,
                now: now,
                resolvedContext: deterministicContext,
                candidates: Array(searchCandidates.prefix(5)),
                recentTurns: Array(recentTurns.suffix(4))
           ) {
            return normalize(interpreted, originalText: text, now: now, resolvedContext: deterministicContext)
        }
        #endif

        var value = await fallback.interpret(
            text: text,
            now: now,
            pinnedContext: pinnedContext,
            searchCandidates: searchCandidates,
            recentTurns: recentTurns
        )
        value.matchedContextID = deterministicContext?.id
        return value
    }

    private func resolvedContext(
        pinned: ContextSearchResult?,
        candidates: [ContextSearchResult]
    ) -> ContextSearchResult? {
        if let pinned { return pinned }
        guard let first = candidates.first else { return nil }
        let secondScore = candidates.dropFirst().first?.score ?? 0
        if first.score >= 75, first.score - secondScore >= 18 { return first }
        return nil
    }

    private func normalize(
        _ value: ConversationInterpretation,
        originalText: String,
        now: Date,
        resolvedContext: ContextSearchResult?
    ) -> ConversationInterpretation {
        var result = value
        if result.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.title = resolvedContext?.title ?? originalText
        }
        result.matchedContextID = resolvedContext?.id
        if result.durationBucket == nil, !result.needsClarification {
            result.durationBucket = .short
            result.inferredFields.insert("duration")
        }
        if result.timeBands.isEmpty, result.durationBucket == .fullDay {
            result.timeBands = [.allDay]
        }
        if result.dateRangeStart == nil || result.dateRangeEnd == nil {
            let range = RuleBasedConversationInterpreter().defaultSearchRange(text: originalText, now: now)
            result.dateRangeStart = result.dateRangeStart ?? range.start
            result.dateRangeEnd = result.dateRangeEnd ?? range.end
        }
        return result
    }
}

struct RuleBasedConversationInterpreter: ConversationInterpreting {
    private let calendar: Calendar

    init(calendar: Calendar = .mira) {
        self.calendar = calendar
    }

    func interpret(
        text: String,
        now: Date,
        pinnedContext: ContextSearchResult?,
        searchCandidates: [ContextSearchResult],
        recentTurns: [ConversationTurnSnapshot]
    ) async -> ConversationInterpretation {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return .unknown(text) }

        let intent = inferIntent(from: normalized, hasContext: pinnedContext != nil || !searchCandidates.isEmpty)
        let durationResult = inferDuration(from: normalized)
        let bandResult = inferBands(from: normalized, duration: durationResult.value)
        let dates = parseDates(from: normalized, now: now)
        let range = defaultSearchRange(text: normalized, now: now)
        let exact = parseExactTime(from: normalized, dates: dates, range: range)
        let title = inferTitle(from: normalized, context: pinnedContext ?? searchCandidates.first)
        let ambiguousActivity = isHighlyAmbiguousActivity(normalized) && durationResult.wasInferred
        let needsClarification = intent == .unknown || ambiguousActivity

        var inferred: Set<String> = []
        if durationResult.wasInferred { inferred.insert("duration") }
        if bandResult.wasInferred { inferred.insert("timeBands") }
        if dates.isEmpty { inferred.insert("dateRange") }

        return ConversationInterpretation(
            intent: intent,
            title: title,
            person: pinnedContext?.subtitle.contains("・") == false ? nil : nil,
            candidateDates: dates,
            dateRangeStart: range.start,
            dateRangeEnd: range.end,
            durationBucket: durationResult.value,
            timeBands: bandResult.value,
            exactStartDate: exact?.start,
            exactEndDate: exact?.end,
            inferredFields: inferred,
            explicitConstraints: inferConstraints(from: normalized),
            needsClarification: needsClarification,
            clarificationQuestion: needsClarification ? clarificationQuestion(for: intent) : nil,
            clarificationOptions: needsClarification ? clarificationOptions(for: intent) : [],
            matchedContextID: pinnedContext?.id,
            confidence: needsClarification ? 0.42 : 0.72,
            source: "ルールベース"
        )
    }

    func defaultSearchRange(text: String, now: Date) -> DateInterval {
        let startOfToday = calendar.startOfDay(for: now)
        if text.contains("来月") {
            let start = MonthKey(date: now.addingMonths(1), calendar: calendar).firstDay
            let end = calendar.date(byAdding: .month, value: 1, to: start)?.addingTimeInterval(-1) ?? start
            return DateInterval(start: start, end: end)
        }
        if text.contains("再来週") {
            let start = startOfWeek(containing: now).addingDays(14, calendar: calendar)
            return DateInterval(start: start, end: start.addingDays(6, calendar: calendar).setting(hour: 23, minute: 59, calendar: calendar))
        }
        if text.contains("来週") {
            let start = startOfWeek(containing: now).addingDays(7, calendar: calendar)
            return DateInterval(start: start, end: start.addingDays(6, calendar: calendar).setting(hour: 23, minute: 59, calendar: calendar))
        }
        if text.contains("今月") {
            let key = MonthKey(date: now, calendar: calendar)
            return DateInterval(start: max(startOfToday, key.firstDay), end: key.interval.end.addingTimeInterval(-1))
        }
        return DateInterval(start: startOfToday, end: startOfToday.addingDays(28, calendar: calendar).setting(hour: 23, minute: 59, calendar: calendar))
    }

    private func inferIntent(from text: String, hasContext: Bool) -> ConversationIntent {
        if text.contains("断り") || text.contains("断る") || text.contains("見送") || text.contains("パスしたい") {
            return .declineInvitation
        }
        if hasContext && (text.contains("になった") || text.contains("変更") || text.contains("ずら") || text.contains("からに") || text.contains("時間にな")) {
            return .updateExisting
        }
        if text.contains("行けそう") || text.contains("いけそう") || text.contains("行ける") || text.contains("空いてる") {
            return .checkInvitation
        }
        if text.contains("いつ") || text.contains("日程") || text.contains("候補") || text.contains("行きたい") || text.contains("企画") || text.contains("遊びたい") {
            return .findDates
        }
        if text.contains("追加") || text.contains("入れと") || text.contains("予定に") {
            return .addEvent
        }
        if hasContext { return .askAboutExisting }
        return .unknown
    }

    private func inferDuration(from text: String) -> (value: DurationBucket?, wasInferred: Bool) {
        if text.contains("終日") || text.contains("一日") || text.contains("1日") || text.contains("丸一日") {
            return (.fullDay, false)
        }
        if text.contains("半日") || text.contains("午前いっぱい") || text.contains("午後いっぱい") {
            return (.halfDay, false)
        }
        if text.range(of: "[1-3１-３]\\s*(時間|h|H)", options: .regularExpression) != nil {
            return (.short, false)
        }

        let fullDayKeywords = ["旅行", "登山", "テーマパーク", "フェス", "遠出", "キャンプ"]
        if fullDayKeywords.contains(where: text.contains) { return (.fullDay, true) }
        let halfDayKeywords = ["美術館", "水族館", "買い物", "イベント", "観劇", "ライブ"]
        if halfDayKeywords.contains(where: text.contains) { return (.halfDay, true) }
        let shortKeywords = ["焼肉", "飲み", "ご飯", "カフェ", "ランチ", "美容院", "病院", "映画", "面談", "打ち合わせ"]
        if shortKeywords.contains(where: text.contains) { return (.short, true) }
        return (nil, true)
    }

    private func inferBands(from text: String, duration: DurationBucket?) -> (value: [SchedulingTimeBand], wasInferred: Bool) {
        var bands: [SchedulingTimeBand] = []
        if text.contains("朝") { bands.append(.morning) }
        if text.contains("昼") || text.contains("ランチ") { bands.append(duration == .halfDay ? .secondHalf : .midday) }
        if text.contains("午前") { bands.append(duration == .halfDay ? .firstHalf : .morning) }
        if text.contains("午後") { bands.append(duration == .halfDay ? .secondHalf : .midday) }
        if text.contains("夜") || text.contains("夕方") { bands.append(.evening) }
        if text.contains("終日") || duration == .fullDay { bands = [.allDay] }
        if !bands.isEmpty { return (Array(Set(bands)).sorted { $0.rawValue < $1.rawValue }, false) }

        if text.contains("焼肉") || text.contains("飲み") || text.contains("ディナー") {
            return ([.evening], true)
        }
        if text.contains("カフェ") || text.contains("ランチ") || text.contains("美容院") || text.contains("映画") {
            return ([.midday], true)
        }
        if duration == .halfDay { return ([.firstHalf, .secondHalf], true) }
        if duration == .fullDay { return ([.allDay], true) }
        return (duration == nil ? [] : [.morning, .midday, .evening], true)
    }

    private func parseDates(from text: String, now: Date) -> [Date] {
        var result: [Date] = []
        let currentYear = calendar.component(.year, from: now)

        if let regex = try? NSRegularExpression(pattern: "(?:(\\d{1,2})月)?(\\d{1,2})日") {
            let nsText = text as NSString
            for match in regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)) {
                let monthString = match.range(at: 1).location == NSNotFound ? nil : nsText.substring(with: match.range(at: 1))
                let dayString = nsText.substring(with: match.range(at: 2))
                let month = Int(monthString ?? "") ?? calendar.component(.month, from: now)
                guard let day = Int(dayString) else { continue }
                var components = DateComponents(year: currentYear, month: month, day: day)
                if let date = calendar.date(from: components) {
                    if date < calendar.startOfDay(for: now) {
                        components.year = currentYear + 1
                    }
                    if let adjusted = calendar.date(from: components) { result.append(adjusted) }
                }
            }
        }

        let weekdayMap: [(String, Int)] = [
            ("日曜", 1), ("日曜日", 1), ("月曜", 2), ("月曜日", 2),
            ("火曜", 3), ("火曜日", 3), ("水曜", 4), ("水曜日", 4),
            ("木曜", 5), ("木曜日", 5), ("金曜", 6), ("金曜日", 6),
            ("土曜", 7), ("土曜日", 7)
        ]
        for (label, weekday) in weekdayMap where text.contains(label) {
            if let date = nextDate(for: weekday, text: text, now: now) { result.append(date) }
        }

        return Array(Set(result.map { calendar.startOfDay(for: $0) })).sorted()
    }

    private func nextDate(for weekday: Int, text: String, now: Date) -> Date? {
        let base: Date
        if text.contains("再来週") {
            base = startOfWeek(containing: now).addingDays(14, calendar: calendar)
        } else if text.contains("来週") {
            base = startOfWeek(containing: now).addingDays(7, calendar: calendar)
        } else {
            base = calendar.startOfDay(for: now)
        }
        let baseWeekday = calendar.component(.weekday, from: base)
        var delta = (weekday - baseWeekday + 7) % 7
        if delta == 0, !text.contains("来週") && !text.contains("再来週") { delta = 7 }
        return base.addingDays(delta, calendar: calendar)
    }

    private func parseExactTime(from text: String, dates: [Date], range: DateInterval) -> DateInterval? {
        guard let regex = try? NSRegularExpression(pattern: "(\\d{1,2})時(半)?"),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let hourRange = Range(match.range(at: 1), in: text),
              let hour = Int(text[hourRange]) else { return nil }
        let minute = match.range(at: 2).location == NSNotFound ? 0 : 30
        let day = dates.first ?? range.start
        let start = day.setting(hour: hour, minute: minute, calendar: calendar)
        let end = start.addingTimeInterval(2 * 60 * 60)
        return DateInterval(start: start, end: end)
    }

    private func inferTitle(from text: String, context: ContextSearchResult?) -> String {
        if let context, text.count < 24 { return context.title }
        var title = text
        let removals = [
            "いついけそう", "いつ行けそう", "行けそう", "いけそう", "日程探して", "候補出して",
            "予定に入れて", "断りたい", "断る文作って", "来月", "来週", "再来週", "今月"
        ]
        for value in removals { title = title.replacingOccurrences(of: value, with: "") }
        title = title.replacingOccurrences(of: "[?？!！]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? (context?.title ?? "新しい予定") : String(title.prefix(40))
    }

    private func inferConstraints(from text: String) -> [String] {
        var values: [String] = []
        if text.contains("夜は無理") || text.contains("夜なし") { values.append("夜を除外") }
        if text.contains("土曜は無理") || text.contains("土曜なし") { values.append("土曜を除外") }
        if text.contains("日曜は無理") || text.contains("日曜なし") { values.append("日曜を除外") }
        return values
    }

    private func isHighlyAmbiguousActivity(_ text: String) -> Bool {
        ["遊びたい", "何かしたい", "みんなで", "集まりたい"].contains(where: text.contains)
    }

    private func clarificationQuestion(for intent: ConversationIntent) -> String {
        switch intent {
        case .unknown: "この内容で、どうしたい？"
        default: "どのくらいの予定になりそう？"
        }
    }

    private func clarificationOptions(for intent: ConversationIntent) -> [String] {
        if intent == .unknown { return ["行けそうか見る", "日程を探す", "予定に入れる", "断る文を作る"] }
        return DurationBucket.allCases.map(\.title)
    }

    private func startOfWeek(containing date: Date) -> Date {
        var calendar = calendar
        calendar.firstWeekday = 2
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? self.calendar.startOfDay(for: date)
    }
}

struct HybridDeclineDraftGenerator: DeclineDraftGenerating {
    private let fallback = TemplateDeclineDraftGenerator()

    func generate(
        title: String,
        person: String?,
        previous: String?,
        softer: Bool,
        audience: DeclineAudience,
        generationIndex: Int
    ) async -> DeclineDraft {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), FoundationModelDeclineGenerator.isAvailable,
           let value = await FoundationModelDeclineGenerator().generateIfAvailable(
                title: title,
                person: person,
                previous: previous,
                softer: softer,
                audience: audience,
                generationIndex: generationIndex
           ) {
            return value
        }
        #endif
        return await fallback.generate(
            title: title,
            person: person,
            previous: previous,
            softer: softer,
            audience: audience,
            generationIndex: generationIndex
        )
    }
}

struct TemplateDeclineDraftGenerator: DeclineDraftGenerating {
    func generate(
        title: String,
        person: String?,
        previous: String?,
        softer: Bool,
        audience: DeclineAudience,
        generationIndex: Int
    ) async -> DeclineDraft {
        let templates: [String]
        switch audience {
        case .friend:
            templates = [
                "誘ってくれてありがとう！今回はちょっと余裕を残しておきたいから見送るね。また誘って〜！",
                "声かけてくれてうれしい！今回はパスするけど、また次ぜひ遊ぼう！",
                "今回は行けなさそう、ごめん！また別の機会に声かけてもらえたらうれしい！"
            ]
        case .coworker:
            templates = [
                "お誘いありがとうございます！今回は予定を詰めすぎないよう見送らせてください。また次の機会にぜひお願いします。",
                "声をかけていただいてありがとうございます。今回は参加を見送ります。またぜひ誘ってください！",
                "お誘いうれしいです。今回は都合をつけず見送ることにしました。また次回よろしくお願いします。"
            ]
        case .supervisor:
            templates = [
                "お声がけいただき、ありがとうございます。大変恐縮ですが、今回は参加を見送らせてください。また機会がございましたら、よろしくお願いいたします。",
                "お誘いいただきありがとうございます。申し訳ありませんが、今回は辞退させていただければと思います。今後ともよろしくお願いいたします。",
                "お心遣いありがとうございます。今回は参加を控えさせていただきます。またの機会がございましたら、ぜひよろしくお願いいたします。"
            ]
        }
        let base = templates[abs(generationIndex) % templates.count]
        let text = softer ? "誘ってくれて本当にありがとう！" + base : base
        return DeclineDraft(
            caseID: nil,
            title: title,
            person: person,
            text: text,
            tone: audience.toneTitle,
            audience: audience,
            generationIndex: generationIndex
        )
    }
}

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
@Generable(description: "A structured interpretation of a casual Japanese calendar request")
private struct GeneratedConversationInterpretation {
    @Guide(description: "One of addEvent, checkInvitation, findDates, declineInvitation, updateExisting, askAboutExisting, unknown")
    var intent: String
    @Guide(description: "A concise event title in Japanese")
    var title: String
    @Guide(description: "Person name if explicitly present, otherwise empty")
    var person: String
    @Guide(description: "One of short, halfDay, fullDay, unknown")
    var duration: String
    @Guide(description: "Allowed values from morning, midday, evening, firstHalf, secondHalf, allDay")
    var timeBands: [String]
    @Guide(description: "Candidate dates formatted yyyy-MM-dd")
    var candidateDates: [String]
    @Guide(description: "Search range start yyyy-MM-dd, or empty")
    var rangeStart: String
    @Guide(description: "Search range end yyyy-MM-dd, or empty")
    var rangeEnd: String
    @Guide(description: "Exact start formatted yyyy-MM-dd'T'HH:mm, or empty")
    var exactStart: String
    @Guide(description: "Exact end formatted yyyy-MM-dd'T'HH:mm, or empty")
    var exactEnd: String
    @Guide(description: "Fields inferred rather than explicitly stated, using duration, timeBands, dateRange")
    var inferredFields: [String]
    @Guide(description: "Short explicit constraints in Japanese")
    var constraints: [String]
    @Guide(description: "Whether one short clarification is truly necessary")
    var needsClarification: Bool
    @Guide(description: "One short Japanese clarification question, or empty")
    var clarificationQuestion: String
    @Guide(description: "Two to four concise answer options")
    var clarificationOptions: [String]
    @Guide(description: "Confidence from 0 to 1")
    var confidence: Double
}

@available(iOS 26.0, *)
private actor FoundationModelConversationInterpreter {
    static var isAvailable: Bool { SystemLanguageModel.default.isAvailable }

    func interpretIfAvailable(
        text: String,
        now: Date,
        resolvedContext: ContextSearchResult?,
        candidates: [ContextSearchResult],
        recentTurns: [ConversationTurnSnapshot]
    ) async -> ConversationInterpretation? {
        guard Self.isAvailable else { return nil }
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        let dayFormatter = DateFormatter()
        dayFormatter.calendar = .mira
        dayFormatter.locale = Locale(identifier: "ja_JP")
        dayFormatter.dateFormat = "yyyy-MM-dd EEEE"

        let candidateText = candidates.enumerated().map { index, candidate in
            "\(index): \(candidate.title) / \(candidate.subtitle)"
        }.joined(separator: "\n")
        let recentText = recentTurns.map { "\($0.role.rawValue): \($0.text)" }.joined(separator: "\n")

        let session = LanguageModelSession(instructions: """
        You are the input parser for a Japanese wellbeing calendar.
        Extract intent and explicit information. You may infer ordinary duration/time bands from event type, but mark inferredFields.
        Do not perform calendar actions, invent people, or invent excuses.
        Ask a clarification only when duration or intent cannot reasonably be inferred.
        Interpret relative dates from the supplied current date.
        """)
        let prompt = """
        Current date: \(dayFormatter.string(from: now))
        Resolved context: \(resolvedContext?.title ?? "none")
        Search candidates:\n\(candidateText)
        Recent conversation:\n\(recentText)
        User input: \(text)
        """

        do {
            let response = try await session.respond(to: prompt, generating: GeneratedConversationInterpretation.self)
            let output = response.content
            let parser = FoundationModelDateParser()
            return ConversationInterpretation(
                intent: ConversationIntent(rawValue: output.intent) ?? .unknown,
                title: output.title,
                person: output.person.isEmpty ? nil : output.person,
                candidateDates: output.candidateDates.compactMap(parser.day),
                dateRangeStart: parser.day(output.rangeStart),
                dateRangeEnd: parser.day(output.rangeEnd)?.setting(hour: 23, minute: 59),
                durationBucket: DurationBucket(rawValue: output.duration),
                timeBands: output.timeBands.compactMap(SchedulingTimeBand.init(rawValue:)),
                exactStartDate: parser.dateTime(output.exactStart),
                exactEndDate: parser.dateTime(output.exactEnd),
                inferredFields: Set(output.inferredFields),
                explicitConstraints: output.constraints,
                needsClarification: output.needsClarification,
                clarificationQuestion: output.clarificationQuestion.isEmpty ? nil : output.clarificationQuestion,
                clarificationOptions: output.clarificationOptions,
                matchedContextID: resolvedContext?.id,
                confidence: min(1, max(0, output.confidence)),
                source: "Apple Foundation Models"
            )
        } catch {
            return nil
        }
    }
}

@available(iOS 26.0, *)
@Generable(description: "A truthful, casual Japanese message declining an invitation")
private struct GeneratedDeclineMessage {
    @Guide(description: "A concise Japanese decline message. Do not invent work, illness, or other false facts.")
    var text: String
    @Guide(description: "A short tone label in Japanese")
    var tone: String
}

@available(iOS 26.0, *)
private actor FoundationModelDeclineGenerator {
    static var isAvailable: Bool { SystemLanguageModel.default.isAvailable }

    func generateIfAvailable(
        title: String,
        person: String?,
        previous: String?,
        softer: Bool,
        audience: DeclineAudience,
        generationIndex: Int
    ) async -> DeclineDraft? {
        guard Self.isAvailable else { return nil }
        let session = LanguageModelSession(instructions: """
        Write a friendly Japanese decline message for an invitation.
        Never invent a false reason such as work or illness.
        It is okay to truthfully say the schedule is crowded or the user wants to preserve personal time.
        Keep the relationship warm and say they would like to be invited again.
        Produce a meaningfully different wording from the previous draft.
        """)
        let prompt = """
        Invitation: \(title)
        Person: \(person ?? "unspecified")
        Softer: \(softer)
        Relationship: \(audience.title)
        Required tone: \(audience.toneTitle)
        Variation number: \(generationIndex)
        Previous draft: \(previous ?? "none")
        """
        do {
            let response = try await session.respond(to: prompt, generating: GeneratedDeclineMessage.self)
            return DeclineDraft(
                caseID: nil,
                title: title,
                person: person,
                text: response.content.text,
                tone: response.content.tone,
                audience: audience,
                generationIndex: generationIndex
            )
        } catch {
            return nil
        }
    }
}

@available(iOS 26.0, *)
private struct FoundationModelDateParser {
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = .mira
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = .mira
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter
    }()

    func day(_ text: String) -> Date? {
        guard !text.isEmpty else { return nil }
        return dayFormatter.date(from: text)
    }

    func dateTime(_ text: String) -> Date? {
        guard !text.isEmpty else { return nil }
        return dateTimeFormatter.date(from: text)
    }
}
#endif
