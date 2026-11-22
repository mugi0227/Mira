import XCTest
@testable import Mira

final class MemoTests: XCTestCase {
    func testAllDayDefaultUsesMemoBehaviorUnlessExplicitlyOccupyingTime() {
        var allDay = TestFixtures.event(day: 10, hour: 0, duration: 24, load: .heavy)
        allDay.isAllDay = true
        let slot = CandidateSlotSnapshot(startDate: TestFixtures.date(day: 10, hour: 18),
            endDate: TestFixtures.date(day: 10, hour: 20), timeOfDay: .evening)
        XCTAssertFalse(allDay.countsAgainstWhitespace)
        XCTAssertTrue(ConflictEngine().conflicts(candidate: slot, events: [allDay], otherCandidates: []).isEmpty)
        XCTAssertEqual(FriendAvailability(date: allDay.startDate, items: [allDay]).summary, "終日空き")
        XCTAssertTrue(FriendDayContent(date: allDay.startDate, items: [allDay], level: .busyTimes).lines.isEmpty)
        XCTAssertTrue(ProposalTimeline.overlappingItems([allDay], proposal: TestFixtures.event(day: 10)).isEmpty)
        allDay.occupiesTime = true
        XCTAssertTrue(allDay.countsAgainstWhitespace)
        XCTAssertFalse(ConflictEngine().conflicts(candidate: slot, events: [allDay], otherCandidates: []).isEmpty)
        XCTAssertEqual(FriendAvailability(date: allDay.startDate, items: [allDay]).summary, "終日予定")
        XCTAssertFalse(FriendDayContent(date: allDay.startDate, items: [allDay], level: .busyTimes).lines.isEmpty)
    }

    func testMemoDoesNotReduceFreeSlotsEvenWithHeavyLoadAndBuffers() {
        let now = TestFixtures.date(day: 1)
        let week = WeekKey(containing: now).adding(weeks: 1)
        var memo = TestFixtures.event(day: 8, hour: 9, duration: 14, load: .veryHeavy, occupiesTime: false)
        memo.bufferBeforeMinutes = 120
        memo.bufferAfterMinutes = 120
        let planner = SelfTimePlanner()
        let empty = planner.propose(week: week, kind: .rest, now: now, items: [], baseRules: [], trend: nil, count: 5)
        let withMemo = planner.propose(week: week, kind: .rest, now: now, items: [memo], baseRules: [], trend: nil, count: 5)
        XCTAssertFalse(memo.countsAgainstWhitespace)
        XCTAssertFalse(empty.isEmpty)
        XCTAssertEqual(empty.map(\.interval), withMemo.map(\.interval))
        XCTAssertEqual(FreeEveningEngine().value(for: memo.startDate, items: [memo]),
                       FreeEveningEngine().value(for: memo.startDate, items: []))
    }

    func testMemoDoesNotConflictWithMarginsOrCandidates() {
        let memo = TestFixtures.event(day: 10, hour: 18, occupiesTime: false)
        let margin = TestFixtures.event(day: 10, hour: 18, kind: .margin, marginKind: .rest)
        let impact = ProtectionEngine().analyze(proposedEvent: memo, month: memo.startDate,
            items: [margin], goals: [TestFixtures.goal(.rest, count: 1)], relocationCandidates: [])
        XCTAssertEqual(impact, .none)
        let candidate = CandidateSlotSnapshot(startDate: memo.startDate, endDate: memo.endDate, timeOfDay: .evening)
        XCTAssertTrue(ConflictEngine().conflictDetails(candidate: candidate, events: [memo], otherCandidates: []).isEmpty)
        XCTAssertFalse(ConflictEngine().conflictDetails(candidate: candidate, events: [margin], otherCandidates: []).isEmpty)
    }

    func testMemoDoesNotChangeFriendAvailability() {
        let memo = TestFixtures.event(day: 10, hour: 9, duration: 14, occupiesTime: false)
        XCTAssertEqual(FriendAvailability(date: memo.startDate, items: [memo]).summary,
                       FriendAvailability(date: memo.startDate, items: []).summary)
        for level in [FriendShareLevel.busyTimes, .titles] {
            XCTAssertEqual(FriendDayContent(date: memo.startDate, items: [memo], level: level).lines,
                           FriendDayContent(date: memo.startDate, items: [], level: level).lines)
        }
        var busy = memo
        busy.occupiesTime = true
        XCTAssertNotEqual(FriendAvailability(date: memo.startDate, items: [busy]).summary,
                          FriendAvailability(date: memo.startDate, items: []).summary)
    }
}
