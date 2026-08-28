import XCTest
@testable import Mira

final class ConversationalAssistantTests: XCTestCase {
    private var calendar: Calendar { .mira }

    func testPastedInvitationIsStructuredWithoutRequiringAgenticTools() async {
        let now = makeDate(2026, 8, 29, 10)
        let interpreter = ProductionConversationInterpreter(calendar: calendar)

        let result = await interpreter.interpret(
            text: "来週の金曜日か土曜日どっちか飲まん？",
            now: now,
            pinnedContext: nil,
            searchCandidates: [],
            recentTurns: []
        )

        XCTAssertEqual(result.intent, .checkInvitation)
        XCTAssertEqual(result.durationBucket, .short)
        XCTAssertEqual(result.timeBands, [.evening])
        XCTAssertEqual(result.candidateDates.count, 2)
        XCTAssertTrue(result.inferredFields.contains("duration"))
        XCTAssertTrue(result.inferredFields.contains("timeBands"))
        XCTAssertFalse(result.needsClarification)
    }

    func testAmbiguousActivityAsksOnlyForDuration() async {
        let interpreter = RuleBasedConversationInterpreter(calendar: calendar)
        let result = await interpreter.interpret(
            text: "来月みんなで遊びたい",
            now: makeDate(2026, 8, 29, 10),
            pinnedContext: nil,
            searchCandidates: [],
            recentTurns: []
        )

        XCTAssertEqual(result.intent, .findDates)
        XCTAssertTrue(result.needsClarification)
        XCTAssertTrue(result.clarificationOptions.contains("半日"))
    }

    func testCaseSearchExcludesPastByDefaultAndIncludesItExplicitly() {
        let now = makeDate(2026, 8, 29, 10)
        let past = CalendarItemSnapshot(
            id: UUID(),
            title: "昔の焼肉会",
            startDate: makeDate(2026, 5, 10, 19),
            endDate: makeDate(2026, 5, 10, 21),
            isAllDay: false,
            kind: .confirmed,
            marginKind: nil,
            loadClass: .normal,
            loadReason: "test",
            bufferBeforeMinutes: 0,
            bufferAfterMinutes: 0,
            isImportantTime: false,
            sourceID: nil
        )
        let future = CalendarItemSnapshot(
            id: UUID(),
            title: "友達と焼肉",
            startDate: makeDate(2026, 9, 12, 19),
            endDate: makeDate(2026, 9, 12, 21),
            isAllDay: false,
            kind: .confirmed,
            marginKind: nil,
            loadClass: .normal,
            loadReason: "test",
            bufferBeforeMinutes: 0,
            bufferAfterMinutes: 0,
            isImportantTime: false,
            sourceID: nil
        )
        let engine = CaseSearchEngine(calendar: calendar)

        let normal = engine.search(
            query: "焼肉",
            includePast: false,
            now: now,
            cases: [],
            items: [past, future],
            adjustments: [],
            invitations: []
        )
        XCTAssertEqual(normal.map(\.title), ["友達と焼肉"])

        let expanded = engine.search(
            query: "焼肉",
            includePast: true,
            now: now,
            cases: [],
            items: [past, future],
            adjustments: [],
            invitations: []
        )
        XCTAssertEqual(Set(expanded.map(\.title)), Set(["昔の焼肉会", "友達と焼肉"]))
    }

    func testCoarseCandidateRoundTripPreservesTimeBandAndDuration() throws {
        let slot = CandidateSlotSnapshot(
            startDate: makeDate(2026, 9, 16, 19),
            endDate: makeDate(2026, 9, 16, 21),
            timeOfDay: .evening,
            schedulingTimeBand: .evening,
            durationBucket: .short,
            exactTimeKnown: false,
            isRecommended: true,
            recommendationScore: 98.0
        )

        let data = try JSONEncoder().encode(slot)
        let decoded = try JSONDecoder().decode(CandidateSlotSnapshot.self, from: data)

        XCTAssertEqual(decoded.schedulingTimeBand, .evening)
        XCTAssertEqual(decoded.durationBucket, .short)
        XCTAssertEqual(decoded.exactTimeKnown, false)
        XCTAssertEqual(decoded.isRecommended, true)
        XCTAssertEqual(decoded.recommendationScore, 98.0)
    }

    private func makeDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
