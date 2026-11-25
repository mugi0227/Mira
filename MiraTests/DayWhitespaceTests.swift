import XCTest
@testable import Mira

final class DayWhitespaceTests: XCTestCase {
    private let day = TestFixtures.date(day: 2)

    func testEmptyDayIsSixteenHoursAndFullRing() {
        let value = measure([])
        XCTAssertEqual(value.availableMinutes, 960)
        XCTAssertEqual(value.fraction, 1)
    }

    func testMeterDirectionShowsComplementaryFractionsAndDurations() {
        let empty = measure([])
        let partial = measure([TestFixtures.event(day: 2, hour: 10, duration: 4)])
        let full = measure([TestFixtures.event(day: 2, hour: 7, duration: 16)])

        XCTAssertEqual([empty, partial, full].map { $0.fraction(for: .remaining) }, [1, 0.75, 0])
        XCTAssertEqual([empty, partial, full].map { $0.fraction(for: .occupied) }, [0, 0.25, 1])
        XCTAssertEqual(partial.durationText(for: .remaining), "12時間")
        XCTAssertEqual(partial.durationText(for: .occupied), "4時間")
    }

    func testWorkAndOverlappingEventsAreOnlyCountedOnce() {
        let events = [TestFixtures.event(day: 2, hour: 10, duration: 2),
                      TestFixtures.event(day: 2, hour: 17, duration: 3)]
        let rules = [BaseAvailabilityRule(weekday: 4, startMinute: 540, endMinute: 1080)]
        let value = measure(events, rules: rules)
        XCTAssertEqual(value.availableMinutes, 300) // 7–9 and 20–23
        XCTAssertEqual(value.fraction, 5.0 / 16, accuracy: 0.001)
    }

    func testMemosBirthdaysProtectedTimeAndBuffersDoNotConsumeWhitespace() {
        var memo = TestFixtures.event(day: 2)
        memo.occupiesTime = false
        var allDay = TestFixtures.event(day: 2, hour: 0, duration: 24)
        allDay.isAllDay = true
        let birthday = TestFixtures.event(day: 2, kind: .birthday)
        let rest = TestFixtures.event(day: 2, kind: .margin, marginKind: .rest)
        var actualEvent = TestFixtures.event(day: 2, hour: 18, duration: 1)
        actualEvent.bufferBeforeMinutes = 60
        actualEvent.bufferAfterMinutes = 60
        XCTAssertEqual(measure([memo, allDay, birthday, rest, actualEvent]).availableMinutes, 900)
        allDay.occupiesTime = true
        XCTAssertEqual(measure([allDay]).availableMinutes, 0)
    }

    func testClipsOvernightEventsAndExcludesOtherDays() {
        let overnight = TestFixtures.event(day: 1, hour: 22, duration: 11)
        let late = TestFixtures.event(day: 2, hour: 22, duration: 5)
        let tomorrow = TestFixtures.event(day: 3)
        XCTAssertEqual(measure([overnight, late, tomorrow]).availableMinutes, 780)
    }

    func testBaseRulesOutsideAwakeWindowAndDuplicatesAreClipped() {
        let rules = [BaseAvailabilityRule(weekday: 4, startMinute: 0, endMinute: 480),
                     BaseAvailabilityRule(weekday: 4, startMinute: 0, endMinute: 480),
                     BaseAvailabilityRule(weekday: 4, startMinute: 1320, endMinute: 1440),
                     BaseAvailabilityRule(weekday: 5, startMinute: 540, endMinute: 1080)]
        XCTAssertEqual(measure([], rules: rules).availableMinutes, 840)
    }

    @MainActor
    func testOccupancyChoiceSurvivesEntityRoundTripAndOldJSON() throws {
        var event = TestFixtures.event(day: 2)
        event.occupiesTime = false
        let entity = CalendarItemEntity(snapshot: event)
        XCTAssertFalse(entity.snapshot.countsAgainstWhitespace)
        event.occupiesTime = true
        entity.apply(event)
        XCTAssertTrue(entity.snapshot.countsAgainstWhitespace)
        let encoded = try JSONEncoder().encode(event)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "occupiesTime")
        let old = try JSONDecoder().decode(CalendarItemSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertTrue(old.countsAgainstWhitespace)
    }

    private func measure(_ items: [CalendarItemSnapshot], rules: [BaseAvailabilityRule] = []) -> DayWhitespace {
        DayWhitespace(date: day, items: items, baseRules: rules)
    }
}
