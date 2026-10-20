import XCTest
@testable import Mira

// Loop goal S4 (docs/loop-goals.md): sharing shows only coarse free bands, never what the plans are.
final class FriendAvailabilityPrivacyTests: XCTestCase {
    private let now = TestFixtures.date(day: 1, hour: 10)

    private var items: [CalendarItemSnapshot] {
        var margin = TestFixtures.event(title: MarginKind.reading.title, day: 4, hour: 19, duration: 3, kind: .margin, marginKind: .reading)
        margin.title = "秘密の読書会"
        return [
            TestFixtures.event(title: "通院（皮膚科）", day: 2, hour: 19, duration: 2),
            margin,
            TestFixtures.event(title: "転職面談", day: 5, hour: 13, duration: 2)
        ]
    }

    func testShareTextNeverContainsTitlesOrMarginKinds() {
        let text = FriendAvailabilityText.text(from: now, items: items)
        for item in items {
            XCTAssertFalse(text.contains(item.title), item.title)
        }
        for kind in MarginKind.allCases {
            XCTAssertFalse(text.contains(kind.title), kind.title)
        }
        let summaries = (0..<14).map { FriendAvailability(date: now.addingDays($0), items: items).summary }.joined()
        for item in items {
            XCTAssertFalse(summaries.contains(item.title), item.title)
        }
    }

    func testShareTextListsOnlyFreeBands() {
        let text = FriendAvailabilityText.text(from: now, items: items)
        XCTAssertTrue(text.hasPrefix("この2週間で空いている時間帯です"))
        let tuesdayLine = text.split(separator: "\n").first { $0.contains("9/2(") }
        XCTAssertNotNil(tuesdayLine)
        XCTAssertFalse(tuesdayLine?.contains("夜") ?? true, "the evening with a plan must not be offered")
        XCTAssertTrue(tuesdayLine?.contains("朝") ?? false)
    }

    func testPastBandsOfTodayAreNotOffered() {
        let evening = TestFixtures.date(day: 1, hour: 19)
        let text = FriendAvailabilityText.text(from: evening, items: [])
        let todayLine = text.split(separator: "\n").first { $0.contains("9/1(") }
        XCTAssertEqual(todayLine.map(String.init), "・9/1(火) 夜")
    }
}
