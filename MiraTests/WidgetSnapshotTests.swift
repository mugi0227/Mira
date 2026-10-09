import XCTest
@testable import Mira

final class WidgetSnapshotTests: XCTestCase {
    func testSnapshotCoversTwoWeeksInOrderWithShortMarginNames() {
        let now = TestFixtures.date(day: 1, hour: 10)
        var colored = TestFixtures.event(title: "友達とご飯", day: 3, hour: 19)
        colored.colorTag = .sky
        let margin = TestFixtures.event(title: MarginKind.rest.title, day: 2, hour: 9, duration: 12, kind: .margin, marginKind: .rest)
        let past = TestFixtures.event(title: "昔の予定", day: 1, hour: 6, duration: 1)
        let tooFar = TestFixtures.event(title: "先の予定", day: 25, hour: 19)

        let snapshot = MiraStore.widgetSnapshot(items: [tooFar, colored, margin, past], now: now)

        XCTAssertEqual(snapshot.entries.map(\.title), ["昔の予定", "休息", "友達とご飯"])
        XCTAssertEqual(snapshot.entries.last?.tintHex, EventColorTag.sky.barHex)
        XCTAssertEqual(snapshot.nextMargin(after: now)?.title, "休息")
        XCTAssertEqual(snapshot.nextPlan(after: now)?.title, "友達とご飯")
        XCTAssertTrue(snapshot.today(at: now).isEmpty, "the 6:00 plan already ended")
    }
}
