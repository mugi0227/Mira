import XCTest
@testable import Mira

final class CalendarDisplayOptionsTests: XCTestCase {
    func testRokuyoUsesLunarMonthAndDayInTokyo() throws {
        let newYear = try date("2026-02-17")
        XCTAssertEqual(CalendarDisplayOptions.rokuyo(for: newYear), "先勝")
        XCTAssertEqual(CalendarDisplayOptions.rokuyo(for: newYear.addingDays(1)), "友引")
        XCTAssertEqual(CalendarDisplayOptions.rokuyo(for: newYear.addingDays(4)), "大安")
    }

    func testWeekNumberUsesSelectedWeekStartAtYearBoundary() throws {
        let day = try date("2021-01-03")
        XCTAssertEqual(CalendarDisplayOptions.weekNumber(for: day, startingOn: .monday), 53)
        XCTAssertEqual(CalendarDisplayOptions.weekNumber(for: day, startingOn: .sunday), 1)
        XCTAssertEqual(WeekStartDay.wednesday.weekdaySymbols, ["水", "木", "金", "土", "日", "月", "火"])
    }

    func testSettingsPersistAndApplyToNewDraftsAndTimeInput() throws {
        let suite = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var options = CalendarDisplayOptions.load(from: defaults)
        options.showsStartTime = false
        options.showsRokuyo = true
        options.labelStyle = .color
        options.daysOff = [1, 7]
        options.defaultsToAllDay = true
        options.minuteInterval = 15
        options.newEventMinutes = 45
        options.save(to: defaults)
        XCTAssertEqual(CalendarDisplayOptions.load(from: defaults), options)
        let day = try date("2026-09-03")
        let draft = options.newEventDraft(on: day)
        XCTAssertTrue(draft.isAllDay)
        XCTAssertEqual(draft.endTime.timeIntervalSince(draft.startTime), 45 * 60)
        XCTAssertEqual(options.timeEntered("18:45", on: day), day.setting(hour: 18, minute: 45))
        XCTAssertNil(options.timeEntered("18:46", on: day))
        XCTAssertNil(options.timeEntered("24:00", on: day))
    }

    func testDuplicateDetectionOnlyRemovesMatchingLocalStandaloneEvents() throws {
        let day = try date("2026-09-03")
        func item(at hour: Int, occupiesTime: Bool? = nil, source: UUID? = nil) -> CalendarItemSnapshot {
            CalendarItemSnapshot(id: UUID(), title: "ランチ", startDate: day.setting(hour: hour),
                                        endDate: day.setting(hour: hour + 1), isAllDay: false, kind: .confirmed, marginKind: nil,
                                        loadClass: .normal, loadReason: "", bufferBeforeMinutes: 0,
                                        bufferAfterMinutes: 0, isImportantTime: false, sourceID: source, occupiesTime: occupiesTime)
        }
        let matching = [item(at: 12), item(at: 12)].sorted { $0.id.uuidString < $1.id.uuidString }
        let kept = matching[0]
        let copy = matching[1]
        let memo = item(at: 12, occupiesTime: false)
        let linked = item(at: 12, source: UUID())
        XCTAssertEqual(CalendarDisplayOptions.duplicateIDs(in: [copy, memo, kept, linked, item(at: 13)]), [copy.id])
        var options = CalendarDisplayOptions()
        XCTAssertEqual(options.startTime(for: kept), "12:00")
        options.showsStartTime = false
        XCTAssertNil(options.startTime(for: kept))
    }

    private func date(_ value: String) throws -> Date {
        try XCTUnwrap(DateFormatter.mira("yyyy-MM-dd").date(from: value))
    }
}
