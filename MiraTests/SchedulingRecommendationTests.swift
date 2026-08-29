import XCTest
@testable import Mira

final class SchedulingRecommendationTests: XCTestCase {
    private var calendar: Calendar { .mira }

    func testRecommendationsAreAdaptiveAndPreselectTwoToFiveCandidates() {
        let engine = SchedulingRecommendationEngine(calendar: calendar)
        let start = makeDate(2026, 9, 1, 0)
        let end = makeDate(2026, 9, 30, 23)

        let values = engine.recommendations(
            title: "友達と焼肉",
            dateRange: DateInterval(start: start, end: end),
            duration: .short,
            timeBands: [.evening],
            items: [],
            heldCandidates: [],
            baseRules: standardWeekdays
        )

        let recommended = values.filter(\.isRecommended)
        XCTAssertGreaterThanOrEqual(recommended.count, 2)
        XCTAssertLessThanOrEqual(recommended.count, 5)
        XCTAssertTrue(recommended.allSatisfy { $0.timeBand == .evening })
    }

    func testHeldCandidateIsAvoidedButRemainsSelectableWithConflict() {
        let engine = SchedulingRecommendationEngine(calendar: calendar)
        let heldDay = makeDate(2026, 9, 12, 0)
        let held = CandidateSlotSnapshot(
            startDate: heldDay.setting(hour: 19),
            endDate: heldDay.setting(hour: 21),
            timeOfDay: .evening,
            schedulingTimeBand: .evening,
            durationBucket: .short,
            exactTimeKnown: false
        )

        let values = engine.recommendations(
            title: "映画",
            dateRange: DateInterval(start: heldDay, end: heldDay.addingDays(2).setting(hour: 23)),
            duration: .short,
            timeBands: [.evening],
            items: [],
            heldCandidates: [held],
            baseRules: []
        )

        let heldResult = values.first { calendar.isDate($0.day, inSameDayAs: heldDay) }
        XCTAssertNotNil(heldResult)
        XCTAssertTrue(heldResult?.conflicts.contains(where: { $0.contains("仮押さえ") }) == true)
        XCTAssertLessThan(heldResult?.score ?? 100, 100)
    }

    func testBaseHoursConflictIsWarningNotHardRemoval() {
        let engine = SchedulingRecommendationEngine(calendar: calendar)
        let monday = makeDate(2026, 9, 7, 0)

        let values = engine.recommendations(
            title: "打ち合わせ",
            dateRange: DateInterval(start: monday, end: monday.setting(hour: 23)),
            duration: .short,
            timeBands: [.midday, .evening],
            items: [],
            heldCandidates: [],
            baseRules: standardWeekdays
        )

        let midday = values.first(where: { $0.timeBand == .midday })
        let evening = values.first(where: { $0.timeBand == .evening })
        XCTAssertNotNil(midday)
        XCTAssertNotNil(evening)
        XCTAssertFalse(midday?.conflicts.isEmpty ?? true)
        XCTAssertTrue(evening?.conflicts.isEmpty ?? false)
        XCTAssertGreaterThan(evening?.score ?? 0, midday?.score ?? 0)
    }

    private var standardWeekdays: [BaseAvailabilityRule] {
        (2...6).map { BaseAvailabilityRule(weekday: $0, startMinute: 9 * 60, endMinute: 18 * 60) }
    }

    private func makeDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
