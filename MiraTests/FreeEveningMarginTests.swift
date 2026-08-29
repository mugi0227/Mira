import XCTest
@testable import Mira

final class FreeEveningMarginTests: XCTestCase {
    func testProtectedSelfTimeStillCountsAsFreeEvening() {
        let day = TestFixtures.date(2026, 9, 8, 0)
        let margin = CalendarItemSnapshot(
            id: UUID(),
            title: MarginKind.reading.title,
            startDate: TestFixtures.date(2026, 9, 8, 19),
            endDate: TestFixtures.date(2026, 9, 8, 22),
            isAllDay: false,
            kind: .margin,
            marginKind: .reading,
            loadClass: .light,
            loadReason: "self time",
            bufferBeforeMinutes: 0,
            bufferAfterMinutes: 0,
            isImportantTime: false,
            sourceID: nil
        )

        XCTAssertEqual(FreeEveningEngine().value(for: day, items: [margin]), 1)
    }

    func testConfirmedEveningCommitmentConsumesFreeEvening() {
        let day = TestFixtures.date(2026, 9, 8, 0)
        let event = CalendarItemSnapshot(
            id: UUID(),
            title: "飲み会",
            startDate: TestFixtures.date(2026, 9, 8, 18),
            endDate: TestFixtures.date(2026, 9, 8, 22),
            isAllDay: false,
            kind: .confirmed,
            marginKind: nil,
            loadClass: .heavy,
            loadReason: "external event",
            bufferBeforeMinutes: 0,
            bufferAfterMinutes: 0,
            isImportantTime: false,
            sourceID: nil
        )

        XCTAssertEqual(FreeEveningEngine().value(for: day, items: [event]), 0)
    }
}
