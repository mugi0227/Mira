import XCTest
@testable import Mira

final class DateDisplayTests: XCTestCase {
    /// CI simulators run in UTC; a 9:00 Tokyo plan must still read 9:00.
    func testTimeDescriptionUsesTheAppTimeZone() {
        let event = TestFixtures.event(title: "仕事", day: 2, hour: 9, duration: 9)
        XCTAssertEqual(event.timeDescription, "9:00–18:00")
    }

    func testShortDateUsesTheAppTimeZone() {
        // 0:30 in Tokyo is still the previous day in UTC.
        let lateNight = TestFixtures.date(day: 5, hour: 0).addingTimeInterval(30 * 60)
        XCTAssertTrue(lateNight.japaneseShortDate.hasPrefix("9月5日"))
    }
}
