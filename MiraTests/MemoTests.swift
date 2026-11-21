import XCTest
@testable import Mira

final class MemoTests: XCTestCase {
    func testMemoDoesNotReduceFreeSlotsEvenWithHeavyLoadAndBuffers() {
        let now = TestFixtures.date(day: 1)
        let week = WeekKey(containing: now).adding(weeks: 1)
        var memo = TestFixtures.event(day: 8, hour: 9, duration: 14, load: .veryHeavy, kind: .memo)
        memo.bufferBeforeMinutes = 120
        memo.bufferAfterMinutes = 120
        let planner = SelfTimePlanner()
        let empty = planner.propose(week: week, kind: .rest, now: now, items: [], baseRules: [], trend: nil, count: 5)
        let withMemo = planner.propose(week: week, kind: .rest, now: now, items: [memo], baseRules: [], trend: nil, count: 5)
        XCTAssertFalse(memo.occupiesTime)
        XCTAssertFalse(empty.isEmpty)
        XCTAssertEqual(empty.map(\.interval), withMemo.map(\.interval))
        XCTAssertEqual(FreeEveningEngine().value(for: memo.startDate, items: [memo]),
                       FreeEveningEngine().value(for: memo.startDate, items: []))
    }

    func testMemoDoesNotConflictWithMarginsOrCandidates() {
        let memo = TestFixtures.event(day: 10, hour: 18, kind: .memo)
        let margin = TestFixtures.event(day: 10, hour: 18, kind: .margin, marginKind: .rest)
        let impact = ProtectionEngine().analyze(proposedEvent: memo, month: memo.startDate,
            items: [margin], goals: [TestFixtures.goal(.rest, count: 1)], relocationCandidates: [])
        XCTAssertEqual(impact, .none)
        let candidate = CandidateSlotSnapshot(startDate: memo.startDate, endDate: memo.endDate, timeOfDay: .evening)
        XCTAssertTrue(ConflictEngine().conflictDetails(candidate: candidate, events: [memo], otherCandidates: []).isEmpty)
        XCTAssertFalse(ConflictEngine().conflictDetails(candidate: candidate, events: [margin], otherCandidates: []).isEmpty)
    }

    func testMemoDoesNotChangeFriendAvailability() {
        let memo = TestFixtures.event(day: 10, hour: 9, duration: 14, kind: .memo)
        XCTAssertEqual(FriendAvailability(date: memo.startDate, items: [memo]).summary,
                       FriendAvailability(date: memo.startDate, items: []).summary)
        var busy = memo
        busy.kind = .confirmed
        XCTAssertNotEqual(FriendAvailability(date: memo.startDate, items: [busy]).summary,
                          FriendAvailability(date: memo.startDate, items: []).summary)
    }
}
