import XCTest
@testable import Mira

final class DayFreeSlotTests: XCTestCase {
    private let day = TestFixtures.date(day: 2)

    func testEmptyDayOffersTheWholeWakingWindow() {
        XCTAssertEqual(measure([]).longestMinutes, 960)
    }

    func testThreeShortGapsDoNotFitWhatOneLongGapDoes() {
        // Free 7–9, 11–13 and 15–23 around two events and nothing else.
        let scattered = [TestFixtures.event(day: 2, hour: 9, duration: 2),
                         TestFixtures.event(day: 2, hour: 13, duration: 2),
                         TestFixtures.event(day: 2, hour: 17, duration: 6)]
        let value = measure(scattered)
        XCTAssertEqual(value.longestMinutes, 120)
        XCTAssertTrue(value.fits(minutes: 120))
        XCTAssertFalse(value.fits(minutes: 180))
    }

    func testBaseRulesAndBuffersTakeTimeButMemosAndMarginsDoNot() {
        let work = BaseAvailabilityRule(weekday: 4, startMinute: 540, endMinute: 1080)
        var dinner = TestFixtures.event(day: 2, hour: 19, duration: 2)
        dinner.bufferBeforeMinutes = 30
        var memo = TestFixtures.event(day: 2, hour: 7, duration: 2)
        memo.occupiesTime = false
        let rest = TestFixtures.event(day: 2, hour: 7, duration: 2, kind: .margin, marginKind: .rest)
        // Free 7–9 (memo and rest don't count), 18–18:30, 21–23.
        XCTAssertEqual(measure([dinner, memo, rest], rules: [work]).longestMinutes, 120)
    }

    func testTodayOnlyCountsWhatIsLeftAndOvernightEventsAreClipped() {
        let now = TestFixtures.date(day: 2, hour: 20)
        XCTAssertEqual(DayFreeSlot(date: day, items: [], baseRules: [], notBefore: now).longestMinutes, 180)
        let overnight = TestFixtures.event(day: 1, hour: 22, duration: 12)
        XCTAssertEqual(measure([overnight]).longestMinutes, 780)
        let late = TestFixtures.date(day: 2, hour: 23)
        XCTAssertFalse(DayFreeSlot(date: day, items: [], baseRules: [], notBefore: late).fits(minutes: 30))
    }

    func testZeroLengthRequestNeverHighlights() {
        XCTAssertFalse(measure([]).fits(minutes: 0))
    }

    private func measure(_ items: [CalendarItemSnapshot], rules: [BaseAvailabilityRule] = []) -> DayFreeSlot {
        DayFreeSlot(date: day, items: items, baseRules: rules)
    }
}
