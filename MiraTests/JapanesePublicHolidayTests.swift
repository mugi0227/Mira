import XCTest
@testable import Mira

final class JapanesePublicHolidayTests: XCTestCase {
    private func date(_ value: String) -> Date {
        DateFormatter.mira("yyyy-MM-dd").date(from: value)!
    }

    func testKnownHolidaysAndWorkDayExclusion() {
        let rules = (2...6).map { BaseAvailabilityRule(weekday: $0, startMinute: 540, endMinute: 1080) }
        for value in ["2026-09-21", "2026-09-22", "2026-09-23", "2026-01-12", "2026-05-06",
                      "2025-11-24", "2026-11-03", "2026-11-23"] {
            let day = date(value)
            XCTAssertTrue(JapanesePublicHolidays.isHoliday(day), value)
            XCTAssertFalse(WorkDayResolver().isWorkDay(day, rules: rules), value)
            XCTAssertTrue(WorkDayResolver().intervals(on: day, rules: rules).isEmpty, value)
            XCTAssertTrue(WorkDayResolver(excludeHolidays: false).isWorkDay(day, rules: rules), value)
            XCTAssertTrue(WorkDayResolver(overrides: [day: true]).isWorkDay(day, rules: rules), value)
        }
        XCTAssertFalse(JapanesePublicHolidays.isHoliday(date("2026-09-24")))
        XCTAssertTrue(WorkDayResolver().isWorkDay(date("2026-09-24"), rules: rules))
    }

    func testHistoricalRulesEquinoxesAndSpecialHolidays() {
        for value in ["2000-01-10", "2000-07-20", "2000-09-15", "2006-05-04", "2009-09-22",
                      "2019-04-30", "2019-05-01", "2019-05-02", "2019-10-22",
                      "2020-07-23", "2020-07-24", "2020-08-10", "2021-08-09",
                      "2026-03-20", "2099-03-20", "2099-09-23"] {
            XCTAssertTrue(JapanesePublicHolidays.isHoliday(date(value)), value)
        }
        for value in ["2019-12-23", "2020-07-20", "2020-08-11", "2020-10-12", "2026-03-21",
                      "1999-01-01", "2100-01-01"] {
            XCTAssertFalse(JapanesePublicHolidays.isHoliday(date(value)), value)
        }
    }
}
