import XCTest
@testable import Mira

final class ConversationalSchedulingTests: XCTestCase {
    func testJapaneseCaseSearchFindsFutureCaseByShortFragment() {
        let now = TestFixtures.date(day: 1, hour: 9)
        let caseEntity = ConversationCaseEntity(
            title: "友達と焼肉",
            kind: .adjustment,
            status: .waiting,
            state: ConversationCaseState(
                dateRangeStart: TestFixtures.date(day: 16, hour: 19),
                dateRangeEnd: TestFixtures.date(day: 16, hour: 21),
                durationBucket: .short,
                allowedTimeBands: [.evening],
                lastIntent: .findDates
            )
        )

        let results = CaseSearchEngine().search(
            query: "焼肉の件さー、夜は無理",
            includePast: false,
            now: now,
            cases: [caseEntity],
            items: [],
            adjustments: [],
            invitations: []
        )

        XCTAssertEqual(results.first?.title, "友達と焼肉")
        XCTAssertEqual(results.first?.relatedCaseID, caseEntity.id)
    }

    func testNormalSearchExcludesPastUntilExplicitlyEnabled() {
        let now = TestFixtures.date(day: 20, hour: 9)
        let past = TestFixtures.event(title: "過去の焼肉", day: 5, hour: 19)

        let normal = CaseSearchEngine().search(
            query: "焼肉",
            includePast: false,
            now: now,
            cases: [],
            items: [past],
            adjustments: [],
            invitations: []
        )
        let expanded = CaseSearchEngine().search(
            query: "焼肉",
            includePast: true,
            now: now,
            cases: [],
            items: [past],
            adjustments: [],
            invitations: []
        )

        XCTAssertTrue(normal.isEmpty)
        XCTAssertEqual(expanded.first?.title, "過去の焼肉")
    }

    func testRuleInterpreterInfersDinnerAndPreservesInferredFields() async {
        let now = TestFixtures.date(day: 1, hour: 9)
        let interpretation = await RuleBasedConversationInterpreter().interpret(
            text: "来週友達と焼肉行きたい",
            now: now,
            pinnedContext: nil,
            searchCandidates: [],
            recentTurns: []
        )

        XCTAssertEqual(interpretation.intent, .findDates)
        XCTAssertEqual(interpretation.durationBucket, .short)
        XCTAssertEqual(interpretation.timeBands, [.evening])
        XCTAssertTrue(interpretation.inferredFields.contains("duration"))
        XCTAssertTrue(interpretation.inferredFields.contains("timeBands"))
        XCTAssertFalse(interpretation.needsClarification)
    }

    func testAmbiguousActivityAsksOnlyForMissingDuration() async {
        let interpretation = await RuleBasedConversationInterpreter().interpret(
            text: "来月みんなで遊びたい",
            now: TestFixtures.date(day: 1, hour: 9),
            pinnedContext: nil,
            searchCandidates: [],
            recentTurns: []
        )

        XCTAssertEqual(interpretation.intent, .findDates)
        XCTAssertTrue(interpretation.needsClarification)
        XCTAssertEqual(interpretation.clarificationOptions, DurationBucket.allCases.map(\.title))
    }

    func testRecommendationEngineReturnsTwoToFiveAndMarksThemRecommended() {
        let range = DateInterval(
            start: TestFixtures.date(day: 2, hour: 0),
            end: TestFixtures.date(day: 24, hour: 23)
        )
        let events = [
            TestFixtures.event(title: "重い予定", day: 6, hour: 9, duration: 9, load: .heavy),
            TestFixtures.event(title: "飲み会", day: 12, hour: 19, duration: 3, load: .heavy)
        ]
        let recommendations = SchedulingRecommendationEngine().recommendations(
            title: "焼肉",
            dateRange: range,
            duration: .short,
            timeBands: [.evening],
            items: events,
            heldCandidates: [],
            baseRules: (2...6).map { BaseAvailabilityRule(weekday: $0, startMinute: 9 * 60, endMinute: 18 * 60) }
        )
        let selected = recommendations.filter(\.isRecommended)

        XCTAssertGreaterThanOrEqual(selected.count, 2)
        XCTAssertLessThanOrEqual(selected.count, 5)
        XCTAssertTrue(selected.allSatisfy { $0.timeBand == .evening })
        XCTAssertTrue(selected.allSatisfy { !$0.reasons.isEmpty })
    }

    func testConflictingCoarseCandidateRemainsAvailableButIsWarned() {
        let day = TestFixtures.date(day: 10, hour: 0)
        let margin = TestFixtures.event(
            title: "読書・映像",
            day: 10,
            hour: 13,
            duration: 5,
            load: .light,
            kind: .margin,
            marginKind: .reading
        )
        let recommendations = SchedulingRecommendationEngine().recommendations(
            title: "カフェ",
            dateRange: DateInterval(start: day, end: day.setting(hour: 23)),
            duration: .short,
            timeBands: [.midday],
            items: [margin],
            heldCandidates: [],
            baseRules: [],
            limitOverride: 1
        )

        XCTAssertEqual(recommendations.count, 1)
        XCTAssertFalse(recommendations[0].conflicts.isEmpty)
        XCTAssertEqual(recommendations[0].timeBand, .midday)
    }

    func testCoarseCandidateRoundTripsThroughCodable() throws {
        let slot = CandidateSlotSnapshot(
            startDate: TestFixtures.date(day: 16, hour: 19),
            endDate: TestFixtures.date(day: 16, hour: 21),
            timeOfDay: .evening,
            schedulingTimeBand: .evening,
            durationBucket: .short,
            exactTimeKnown: false,
            isRecommended: true,
            recommendationScore: 98
        )

        let data = try JSONEncoder().encode(slot)
        let decoded = try JSONDecoder().decode(CandidateSlotSnapshot.self, from: data)

        XCTAssertEqual(decoded.schedulingTimeBand, .evening)
        XCTAssertEqual(decoded.durationBucket, .short)
        XCTAssertEqual(decoded.exactTimeKnown, false)
        XCTAssertEqual(decoded.isRecommended, true)
    }
}

final class MarginRecommendationTests: XCTestCase {
    func testComfortLevelScalesLoadDerivedTargets() {
        let events = (1...8).map {
            TestFixtures.event(title: "外出\($0)", day: $0 * 3, hour: 10, duration: 7, load: .heavy)
        }
        let engine = MarginRecommendationEngine()
        let low = engine.recommend(month: TestFixtures.september, items: events, comfort: .low)
        let standard = engine.recommend(month: TestFixtures.september, items: events, comfort: .standard)
        let high = engine.recommend(month: TestFixtures.september, items: events, comfort: .high)

        XCTAssertLessThanOrEqual(low.targets[.rest, default: 0], standard.targets[.rest, default: 0])
        XCTAssertLessThanOrEqual(standard.targets[.rest, default: 0], high.targets[.rest, default: 0])
        XCTAssertLessThanOrEqual(low.targets[.freeEvening, default: 0], high.targets[.freeEvening, default: 0])
    }
}
