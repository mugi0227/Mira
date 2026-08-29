import XCTest
@testable import Mira

final class MarginRecommendationLoadTests: XCTestCase {
    private var calendar: Calendar { .mira }

    func testHeavierMonthReceivesMoreRestThanQuietMonth() {
        let engine = MarginRecommendationEngine(calendar: calendar)
        let month = makeDate(2026, 9, 1, 0)
        let quiet = [event(day: 5, load: .light)]
        let heavy = (1...8).map { event(day: $0 * 3, load: $0.isMultiple(of: 2) ? .veryHeavy : .heavy) }

        let quietRecommendation = engine.recommend(month: month, items: quiet, comfort: .standard)
        let heavyRecommendation = engine.recommend(month: month, items: heavy, comfort: .standard)

        XCTAssertGreaterThan(
            heavyRecommendation.targets[.rest, default: 0],
            quietRecommendation.targets[.rest, default: 0]
        )
        XCTAssertNil(heavyRecommendation.targets[.freeEvening])
        XCTAssertNil(heavyRecommendation.targets[.solo])
    }

    func testComfortLevelsAreMonotonic() {
        let engine = MarginRecommendationEngine(calendar: calendar)
        let month = makeDate(2026, 9, 1, 0)
        let items = (1...5).map { event(day: $0 * 4, load: .heavy) }

        let low = engine.recommend(month: month, items: items, comfort: .low)
        let standard = engine.recommend(month: month, items: items, comfort: .standard)
        let high = engine.recommend(month: month, items: items, comfort: .high)

        for kind in [MarginKind.rest, .reading, .personalProject] {
            XCTAssertLessThanOrEqual(low.targets[kind, default: 0], standard.targets[kind, default: 0])
            XCTAssertLessThanOrEqual(standard.targets[kind, default: 0], high.targets[kind, default: 0])
        }
    }

    func testLegacyRestAliasesCanonicalizeWithoutRemainingSelectable() {
        XCTAssertEqual(MarginKind.freeEvening.canonicalKind, .rest)
        XCTAssertEqual(MarginKind.solo.canonicalKind, .rest)
        XCTAssertFalse(MarginKind.userSelectableCases.contains(.freeEvening))
        XCTAssertFalse(MarginKind.userSelectableCases.contains(.solo))
    }

    private func event(day: Int, load: LoadClass) -> CalendarItemSnapshot {
        let start = makeDate(2026, 9, min(day, 28), 12)
        return CalendarItemSnapshot(
            id: UUID(),
            title: "予定",
            startDate: start,
            endDate: start.addingTimeInterval(3 * 60 * 60),
            isAllDay: false,
            kind: .confirmed,
            marginKind: nil,
            loadClass: load,
            loadReason: "test",
            bufferBeforeMinutes: 0,
            bufferAfterMinutes: 0,
            isImportantTime: false,
            sourceID: nil
        )
    }

    private func makeDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
