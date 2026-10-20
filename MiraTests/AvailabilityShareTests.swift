import XCTest
@testable import Mira

// Loop goal S4 (docs/loop-goals.md): shareable free slots that leak nothing private.
final class AvailabilityShareTests: XCTestCase {
    private let calendar = Calendar.mira
    private let now = DemoClock.standard.now
    private let engine = AvailabilityShareEngine()

    func testOpenSlotsAvoidEventsMarginsAndBaseRules() {
        let items = sampleItems()
        let rules = [BaseAvailabilityRule(weekday: 4, startMinute: 18 * 60, endMinute: 24 * 60)]
        let days = engine.publicDays(rule: AvailabilityShareRule(startDate: now), items: items, baseRules: rules)
        let slots = engine.openSlots(in: days)

        XCTAssertFalse(slots.isEmpty)
        for slot in slots {
            XCTAssertFalse(items.contains { $0.occupiedInterval.intersects(slot) && $0.occupiedInterval.intersection(with: slot)?.duration ?? 0 > 0 })
            XCTAssertNotEqual(calendar.component(.weekday, from: slot.start), 4)
            XCTAssertGreaterThanOrEqual(slot.duration, 2 * 3600)
            XCTAssertGreaterThanOrEqual(slot.start, now)
        }
    }

    func testBusyTimeIsShownOnlyAsBusy() throws {
        let items = sampleItems()
        let days = engine.publicDays(rule: AvailabilityShareRule(startDate: now), items: items, baseRules: [])
        let eventDay = try XCTUnwrap(days.first { calendar.isDate($0.date, inSameDayAs: items[0].startDate) })
        XCTAssertTrue(eventDay.blocks.contains { $0.state == .busy && $0.state.label == "予定あり" })
        let marginDay = try XCTUnwrap(days.first { calendar.isDate($0.date, inSameDayAs: items[1].startDate) })
        XCTAssertTrue(marginDay.blocks.contains { $0.state == .busy })
    }

    func testShareTextLeaksNoTitlesOrMarginKinds() {
        let items = sampleItems()
        let days = engine.publicDays(rule: AvailabilityShareRule(startDate: now), items: items, baseRules: [])
        let text = engine.shareText(for: days)
        XCTAssertTrue(text.contains("空いています"))
        for item in items {
            XCTAssertFalse(text.contains(item.title), item.title)
        }
        for kind in MarginKind.allCases {
            XCTAssertFalse(text.contains(kind.title), kind.title)
        }
    }

    private func sampleItems() -> [CalendarItemSnapshot] {
        let thursday = now.addingDays(2)
        let friday = now.addingDays(3)
        return [
            item("通院（皮膚科）", on: thursday, hour: 19, hours: 2, kind: .confirmed),
            item(MarginKind.solo.title, on: friday, hour: 18, hours: 4, kind: .margin)
        ]
    }

    private func item(_ title: String, on day: Date, hour: Int, hours: Int, kind: CalendarItemKind) -> CalendarItemSnapshot {
        let start = day.setting(hour: hour)
        return CalendarItemSnapshot(
            id: UUID(), title: title, startDate: start, endDate: start.addingTimeInterval(Double(hours) * 3600),
            isAllDay: false, kind: kind, marginKind: kind == .margin ? .solo : nil, loadClass: .normal, loadReason: "test",
            bufferBeforeMinutes: 0, bufferAfterMinutes: 0, isImportantTime: false, sourceID: nil
        )
    }
}
