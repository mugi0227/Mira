import XCTest
@testable import Mira

final class AdjustmentSegmentTests: XCTestCase {
    func testOnlyUnfinishedAdjustmentsAreInProgress() {
        XCTAssertTrue(AdjustmentSegment.adjustments.includes(.draft))
        XCTAssertTrue(AdjustmentSegment.adjustments.includes(.waiting))
        XCTAssertFalse(AdjustmentSegment.adjustments.includes(.confirmed))
        XCTAssertFalse(AdjustmentSegment.adjustments.includes(.cancelled))
    }

    func testOnlyConfirmedAdjustmentsAreCompleted() {
        for status in [AdjustmentStatus.draft, .waiting, .confirmed, .cancelled] {
            XCTAssertEqual(AdjustmentSegment.confirmed.includes(status), status == .confirmed)
            XCTAssertFalse(AdjustmentSegment.pending.includes(status))
        }
    }

    func testEmptyAndCancelledListsStayEmpty() {
        let empty: [AdjustmentStatus] = []
        for segment in AdjustmentSegment.allCases {
            XCTAssertTrue(empty.filter(segment.includes).isEmpty)
            XCTAssertTrue([AdjustmentStatus.cancelled].filter(segment.includes).isEmpty)
        }
    }
}
