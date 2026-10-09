import Foundation

/// A chat agent answers one turn by calling Mira's tools and writing a reply
/// into the sink. Tools only read or propose; the person approves changes.
@MainActor
protocol MiraChatAgent: AnyObject {
    var displayName: String { get }
    func respond(to text: String, store: MiraStore, sink: ChatTurnSink) async throws
}

enum MiraChatAgentFactory {
    @MainActor
    static func make() -> any MiraChatAgent {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), FoundationModelsChatAgent.isAvailable {
            return FoundationModelsChatAgent()
        }
        #endif
        return RuleBasedChatAgent()
    }
}

/// Works on every device: reads the request with the existing interpreter and
/// drives the same tools the on-device model uses.
@MainActor
final class RuleBasedChatAgent: MiraChatAgent {
    let displayName = "Mira（ルール）"

    func respond(to text: String, store: MiraStore, sink: ChatTurnSink) async throws {
        var interpretation = await store.conversationInterpreter.interpret(
            text: text,
            now: store.now,
            pinnedContext: nil,
            searchCandidates: [],
            recentTurns: []
        )
        interpretation.title = Self.planTitle(from: interpretation.title)
        let calendar = Calendar.mira
        let today = calendar.startOfDay(for: store.now)
        let rangeStart = interpretation.dateRangeStart ?? interpretation.candidateDates.min() ?? today
        let rangeEnd = interpretation.dateRangeEnd
            ?? interpretation.candidateDates.max().map { calendar.date(byAdding: .day, value: 1, to: $0) ?? $0 }
            ?? calendar.date(byAdding: .day, value: 14, to: rangeStart) ?? rangeStart

        switch interpretation.intent {
        case .addEvent where interpretation.exactStartDate != nil:
            let start = interpretation.exactStartDate ?? rangeStart
            let duration = TimeInterval((interpretation.durationBucket ?? .short).representativeMinutes * 60)
            let end = interpretation.exactEndDate ?? start.addingTimeInterval(duration)
            let result = await store.toolProposeEvent(title: interpretation.title, start: start, end: end, isAllDay: false)
            sink.record(result)
            sink.setText(proposalReply(for: result))

        case .addEvent, .findDates, .checkInvitation:
            let result = store.toolFindOpenSlots(
                purpose: interpretation.title,
                from: rangeStart,
                to: rangeEnd,
                duration: interpretation.durationBucket ?? .short,
                bands: interpretation.timeBands
            )
            sink.record(result)
            sink.setText(result.card == nil
                ? "\(store.rangeLabel(rangeStart, rangeEnd))は、余白を崩さずに入れられる枠が見つからなかったにゃ。期間を広げてみる？"
                : "余白を守れる候補を探したにゃ。気になる枠をタップすると、そのまま予定の案にできるよ。")

        case .declineInvitation:
            let draft = await store.declineDraftText(title: interpretation.title, person: interpretation.person, audience: .friend)
            sink.record(store.toolDraftMessage(purpose: "お断り", text: draft))
            sink.setText("角が立たない断り方を考えたにゃ。そのまま使っても、少し直してもいいよ。断るのは悪いことじゃないにゃ。")

        case .updateExisting:
            if let day = interpretation.candidateDates.first ?? interpretation.dateRangeStart {
                let result = store.toolProposeMove(titleQuery: interpretation.title, to: day)
                sink.record(result)
                sink.setText(result.card == nil ? "どの予定のことか分からなかったにゃ。予定の名前を入れてもう一度教えてね。" : proposalReply(for: result))
            } else {
                sink.setText("いつに動かしたいか教えてくれたら、影響をチェックするにゃ。")
            }

        case .askAboutExisting, .unknown:
            if Self.isBalanceQuestion(text) {
                let result = store.toolMonthBalance(month: store.selectedMonth)
                sink.record(result)
                sink.setText("今月の余白の様子だにゃ。足りないところがあれば、空いている日に置く案も出せるよ。")
            } else if interpretation.intent == .askAboutExisting || Self.isScheduleQuestion(text) {
                let end = interpretation.dateRangeEnd ?? calendar.date(byAdding: .day, value: 7, to: rangeStart) ?? rangeStart
                let result = store.toolListSchedule(from: rangeStart, to: end)
                sink.record(result)
                sink.setText(result.card == nil ? "\(store.rangeLabel(rangeStart, end))は何も入っていないにゃ。のんびりできそう。" : "\(store.rangeLabel(rangeStart, end))の予定だにゃ。")
            } else {
                sink.setText("予定のことなら任せてにゃ。たとえば「来週ご飯に行ける日を探して」「土曜の誘いを断る文を作って」「今月ちゃんと休めてる？」みたいに話しかけてね。")
            }
        }
    }

    private func proposalReply(for result: MiraToolResult) -> String {
        switch result.card {
        case .eventProposal(let proposal) where proposal.needsCare:
            return "入れることはできるけど、気になる点があるにゃ。カードを見て決めてね。"
        case .moveProposal(let proposal) where proposal.needsCare:
            return "動かせるけど、ぶつかるものがあるにゃ。カードで確認してね。"
        case .eventProposal, .moveProposal:
            return "問題なさそうだにゃ。よければカードのボタンで決めてね。"
        default:
            return result.summary
        }
    }

    /// Turns a request like "来週、友達とご飯に行ける日を探して" into "友達とご飯".
    static func planTitle(from raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let leadingWords = ["再来週", "来週", "今週", "来月", "今月", "週末", "明日", "明後日", "今日", "今度", "土曜", "日曜", "の", "に", "は"]
        var trimmed = true
        while trimmed {
            trimmed = false
            value = value.trimmingCharacters(in: CharacterSet(charactersIn: "、。,. 　"))
            for word in leadingWords where value.hasPrefix(word) && value.count > word.count {
                value.removeFirst(word.count)
                trimmed = true
            }
        }
        let requestEndings = [
            "に行ける日を探して", "に行ける日ある？", "の日を探して", "できる日を探して", "の日程を探して",
            "を予定に追加して", "を予定に入れて", "を入れて", "を追加して", "に行きたい", "行きたい",
            "したい", "を探して", "探して", "の誘いを断りたい", "を断りたい", "を断る文を作って", "断りたい"
        ]
        for ending in requestEndings where value.hasSuffix(ending) && value.count > ending.count {
            value.removeLast(ending.count)
            break
        }
        value = value.trimmingCharacters(in: CharacterSet(charactersIn: "、。,. 　"))
        return value.isEmpty ? "予定" : value
    }

    static func isBalanceQuestion(_ text: String) -> Bool {
        ["休め", "休息", "余白", "疲れ", "バランス", "詰め込み", "忙しすぎ"].contains { text.contains($0) }
    }

    static func isScheduleQuestion(_ text: String) -> Bool {
        ["予定", "今日", "明日", "今週", "来週", "週末", "空いて", "何がある"].contains { text.contains($0) }
    }
}

#if canImport(FoundationModels)
import FoundationModels

/// Lets tools reach the store and the visible turn without capturing them.
@MainActor
final class MiraToolContext {
    weak var store: MiraStore?
    weak var sink: ChatTurnSink?

    func run(_ body: @MainActor (MiraStore) async -> MiraToolResult) async -> String {
        guard let store else { return "カレンダーにアクセスできませんでした。" }
        let result = await body(store)
        sink?.record(result)
        return result.summary
    }
}

/// On-device agent: the model plans, calls Mira's tools, and replies with
/// streamed text. One session is kept so follow-ups have context.
@available(iOS 26.0, *)
@MainActor
final class FoundationModelsChatAgent: MiraChatAgent {
    static var isAvailable: Bool { SystemLanguageModel.default.isAvailable }

    let displayName = "Mira（Apple Intelligence）"
    private let context = MiraToolContext()
    private var session: LanguageModelSession?

    func respond(to text: String, store: MiraStore, sink: ChatTurnSink) async throws {
        context.store = store
        context.sink = sink
        let prompt = "今は\(Self.nowText(store.now))。\n\(text)"
        do {
            try await stream(prompt, into: sink)
        } catch let error as LanguageModelSession.GenerationError {
            if case .exceededContextWindowSize = error {
                // Start fresh rather than fail; the calendar itself is the memory.
                session = nil
                try await stream(prompt, into: sink)
            } else {
                throw error
            }
        }
    }

    private func stream(_ prompt: String, into sink: ChatTurnSink) async throws {
        let session = self.session ?? makeSession()
        self.session = session
        let responseStream = session.streamResponse(to: prompt)
        for try await snapshot in responseStream {
            sink.setText(snapshot.content)
        }
    }

    private func makeSession() -> LanguageModelSession {
        LanguageModelSession(
            tools: [
                ListScheduleTool(context: context),
                FindOpenSlotsTool(context: context),
                ProposeEventTool(context: context),
                ProposeMoveTool(context: context),
                MonthBalanceTool(context: context),
                DraftMessageTool(context: context)
            ],
            instructions: Self.instructions
        )
    }

    static let instructions = """
    あなたは「Mira」。予定管理アプリの、やさしい猫のアシスタント。語尾は時々「にゃ」。返事は日本語で2〜3文、短く。
    利用者は誘いが多く断るのが苦手。自分の休息・読書・一人時間（＝余白）を守りながら予定を入れたい。
    ルール：
    - 予定や空きについて答える前に、必ずツールでカレンダーを確認する。推測で日付や予定を言わない。
    - 予定の追加・移動は proposeEvent / proposeMove で「案」を作るだけ。保存は本人がカードで決める。保存したとは言わない。
    - 空きを聞かれたら findOpenSlots。余白や基本時間とぶつからない候補だけを勧める。
    - 断りたい時は draftMessage で、正直で角の立たない短い文面を作る。断ることを責めない。
    - 余白を削る案は、別の日に余白を移せることも添える。
    - 日付は yyyy-MM-dd、日時は yyyy-MM-dd'T'HH:mm で渡す。
    """

    static func nowText(_ date: Date) -> String {
        DateFormatter.mira("yyyy-MM-dd'T'HH:mm (EEEE)").string(from: date)
    }
}

private enum ToolDates {
    static let day = DateFormatter.mira("yyyy-MM-dd", locale: Locale(identifier: "en_US_POSIX"))
    static let dateTime = DateFormatter.mira("yyyy-MM-dd'T'HH:mm", locale: Locale(identifier: "en_US_POSIX"))

    static func parseDay(_ text: String) -> Date? {
        day.date(from: text.trimmingCharacters(in: .whitespaces)) ?? dateTime.date(from: text).map { Calendar.mira.startOfDay(for: $0) }
    }

    static func parseDateTime(_ text: String) -> Date? {
        dateTime.date(from: text.trimmingCharacters(in: .whitespaces)) ?? day.date(from: text)
    }

    /// End dates from the model are inclusive days; ranges here are half-open.
    static func dayAfter(_ date: Date) -> Date {
        Calendar.mira.date(byAdding: .day, value: 1, to: date) ?? date
    }
}

@available(iOS 26.0, *)
struct ListScheduleTool: Tool {
    let name = "listSchedule"
    let description = "期間内の予定と余白を一覧する。予定について答える前に使う。"
    let context: MiraToolContext

    @Generable
    struct Arguments {
        @Guide(description: "開始日 yyyy-MM-dd")
        var startDate: String
        @Guide(description: "終了日（この日を含む） yyyy-MM-dd")
        var endDate: String
    }

    func call(arguments: Arguments) async throws -> String {
        guard let start = ToolDates.parseDay(arguments.startDate) else { return "開始日を yyyy-MM-dd で指定してください。" }
        let end = ToolDates.dayAfter(ToolDates.parseDay(arguments.endDate) ?? start)
        return await context.run { $0.toolListSchedule(from: start, to: end) }
    }
}

@available(iOS 26.0, *)
struct FindOpenSlotsTool: Tool {
    let name = "findOpenSlots"
    let description = "余白・基本時間・他の予定とぶつからない候補日時を探す。"
    let context: MiraToolContext

    @Generable
    struct Arguments {
        @Guide(description: "何のための枠か。例：友達とご飯")
        var purpose: String
        @Guide(description: "探す開始日 yyyy-MM-dd")
        var startDate: String
        @Guide(description: "探す終了日（この日を含む） yyyy-MM-dd")
        var endDate: String
        @Guide(description: "長さ。short（1〜2時間）、halfDay、fullDay のいずれか")
        var duration: String
        @Guide(description: "希望の時間帯。morning, midday, evening のいずれか。指定なしは空")
        var timeBands: [String]
    }

    func call(arguments: Arguments) async throws -> String {
        guard let start = ToolDates.parseDay(arguments.startDate) else { return "開始日を yyyy-MM-dd で指定してください。" }
        let end = ToolDates.dayAfter(ToolDates.parseDay(arguments.endDate) ?? start)
        let duration = DurationBucket(rawValue: arguments.duration) ?? .short
        let bands = arguments.timeBands.compactMap(SchedulingTimeBand.init(rawValue:))
        let purpose = arguments.purpose
        return await context.run {
            $0.toolFindOpenSlots(purpose: purpose, from: start, to: end, duration: duration, bands: bands)
        }
    }
}

@available(iOS 26.0, *)
struct ProposeEventTool: Tool {
    let name = "proposeEvent"
    let description = "予定の追加案を作り、余白への影響を調べる。保存はしない。"
    let context: MiraToolContext

    @Generable
    struct Arguments {
        @Guide(description: "予定のタイトル。例：友達とご飯")
        var title: String
        @Guide(description: "開始 yyyy-MM-dd'T'HH:mm")
        var start: String
        @Guide(description: "終了 yyyy-MM-dd'T'HH:mm。不明なら空")
        var end: String
        @Guide(description: "終日の予定か")
        var isAllDay: Bool
    }

    func call(arguments: Arguments) async throws -> String {
        guard let start = ToolDates.parseDateTime(arguments.start) else { return "開始日時を yyyy-MM-dd'T'HH:mm で指定してください。" }
        let end = ToolDates.parseDateTime(arguments.end) ?? start.addingTimeInterval(2 * 3600)
        let title = arguments.title
        let isAllDay = arguments.isAllDay
        return await context.run { await $0.toolProposeEvent(title: title, start: start, end: end, isAllDay: isAllDay) }
    }
}

@available(iOS 26.0, *)
struct ProposeMoveTool: Tool {
    let name = "proposeMove"
    let description = "既存の予定を別の日へ動かす案を作り、影響を調べる。動かしはしない。"
    let context: MiraToolContext

    @Generable
    struct Arguments {
        @Guide(description: "動かしたい予定の名前の一部。例：飲み会")
        var title: String
        @Guide(description: "移動先の日 yyyy-MM-dd")
        var newDate: String
    }

    func call(arguments: Arguments) async throws -> String {
        guard let day = ToolDates.parseDay(arguments.newDate) else { return "移動先を yyyy-MM-dd で指定してください。" }
        let title = arguments.title
        return await context.run { $0.toolProposeMove(titleQuery: title, to: day) }
    }
}

@available(iOS 26.0, *)
struct MonthBalanceTool: Tool {
    let name = "monthBalance"
    let description = "その月の予定の多さと、休息などの余白目標の達成状況を調べる。"
    let context: MiraToolContext

    @Generable
    struct Arguments {
        @Guide(description: "その月の任意の日 yyyy-MM-dd")
        var date: String
    }

    func call(arguments: Arguments) async throws -> String {
        let date = ToolDates.parseDay(arguments.date)
        return await context.run { $0.toolMonthBalance(month: date ?? $0.selectedMonth) }
    }
}

@available(iOS 26.0, *)
struct DraftMessageTool: Tool {
    let name = "draftMessage"
    let description = "友達に送る短いメッセージ（お断り・日程の提案など）をカードにする。"
    let context: MiraToolContext

    @Generable
    struct Arguments {
        @Guide(description: "目的。例：お断り、日程の提案")
        var purpose: String
        @Guide(description: "そのまま送れる短い日本語のメッセージ本文")
        var text: String
    }

    func call(arguments: Arguments) async throws -> String {
        let purpose = arguments.purpose
        let text = arguments.text
        return await context.run { $0.toolDraftMessage(purpose: purpose, text: text) }
    }
}
#endif
