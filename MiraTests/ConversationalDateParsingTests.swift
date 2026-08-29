import XCTest
@testable import Mira

final class ConversationalDateParsingTests: XCTestCase {
    private var calendar: Calendar { .mira }

    func testSlashDateInvitationParsesCandidateDate() async {
        let interpreter = ProductionConversationInterpreter(calendar: calendar)
        let result = await interpreter.interpret(
            text: "9/12これ誘われたわ、いけそう？",
            now: makeDate(2026, 8, 29, 10, 0),
            pinnedContext: nil,
            searchCandidates: [],
            recentTurns: []
        )

        XCTAssertEqual(result.intent, .checkInvitation)
        XCTAssertEqual(result.candidateDates.count, 1)
        XCTAssertEqual(calendar.component(.month, from: result.candidateDates[0]), 9)
        XCTAssertEqual(calendar.component(.day, from: result.candidateDates[0]), 12)
    }

    func testFullWidthDateAndColonTimeAreNormalized() async {
        let interpreter = ProductionConversationInterpreter(calendar: calendar)
        let result = await interpreter.interpret(
            text: "９／１６の焼肉、１９:３０からになった",
            now: makeDate(2026, 8, 29, 10, 0),
            pinnedContext: ContextSearchResult(
                id: UUID(),
                kind: .confirmedEvent,
                title: "焼肉",
                subtitle: "確定予定",
                startDate: makeDate(2026, 9, 16, 19, 0),
                endDate: makeDate(2026, 9, 16, 21, 0),
                relatedCaseID: nil,
                relatedItemID: UUID(),
                relatedAdjustmentID: nil,
                relatedInvitationID: nil,
                score: 100,
                isPast: false
            ),
            searchCandidates: [],
            recentTurns: []
        )

        XCTAssertEqual(result.intent, .updateExisting)
        XCTAssertEqual(result.candidateDates.count, 1)
        XCTAssertNotNil(result.exactStartDate)
        XCTAssertEqual(calendar.component(.hour, from: result.exactStartDate!), 19)
        XCTAssertEqual(calendar.component(.minute, from: result.exactStartDate!), 30)
    }

    func testTomorrowCreatesOneDayRange() async {
        let interpreter = ProductionConversationInterpreter(calendar: calendar)
        let now = makeDate(2026, 8, 29, 10, 0)
        let result = await interpreter.interpret(
            text: "明日カフェ行けそう？",
            now: now,
            pinnedContext: nil,
            searchCandidates: [],
            recentTurns: []
        )

        XCTAssertEqual(result.candidateDates.count, 1)
        XCTAssertTrue(calendar.isDate(result.candidateDates[0], inSameDayAs: now.addingDays(1)))
    }

    private func makeDate(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int
    ) -> Date {
        calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }
}
