import XCTest
@testable import Mira

final class LoadEngineTests: XCTestCase {
    private let engine = LoadEngine(calendar: .mira)

    func testAllDaySalonIsNotVeryHeavy() {
        let result = engine.evaluate(
            title: "美容院",
            startDate: TestFixtures.date(day: 6, hour: 9),
            endDate: TestFixtures.date(day: 6, hour: 21),
            isAllDay: true
        )
        XCTAssertLessThan(result.loadClass, .veryHeavy)
        XCTAssertEqual(result.category, "outing")
    }

    func testAllDayHikingIsVeryHeavy() {
        let result = engine.evaluate(
            title: "富士登山",
            startDate: TestFixtures.date(day: 6, hour: 5),
            endDate: TestFixtures.date(day: 6, hour: 22),
            isAllDay: true
        )
        XCTAssertEqual(result.loadClass, .veryHeavy)
        XCTAssertGreaterThanOrEqual(result.bufferAfterMinutes, 120)
    }

    func testBirthdayHasLowTimeLoad() {
        let result = engine.evaluate(
            title: "友達の誕生日",
            startDate: TestFixtures.date(day: 7, hour: 9),
            endDate: TestFixtures.date(day: 7, hour: 21),
            isAllDay: true
        )
        XCTAssertEqual(result.loadClass, .light)
        XCTAssertFalse(result.likelyOutsideHome)
    }

    func testExplicitRuleHasPriority() {
        let result = engine.evaluate(
            title: "会社の飲み会",
            startDate: TestFixtures.date(day: 8, hour: 19),
            endDate: TestFixtures.date(day: 8, hour: 22),
            isAllDay: false,
            explicitRules: [LoadRule(keyword: "飲み会", loadClass: .light)]
        )
        XCTAssertEqual(result.loadClass, .light)
        XCTAssertEqual(result.source, "user")
    }
}
