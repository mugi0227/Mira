import XCTest
@testable import Mira

final class FuturePlacementTests: XCTestCase {
    func testMidMonthProposalOnlyUsesTimeThatHasNotStarted() {
        let now = TestFixtures.date(day: 16, hour: 14)
        let proposal = SchedulerEngine(calendar: .mira).propose(
            month: TestFixtures.september,
            goals: [TestFixtures.goal(.rest, count: 3), TestFixtures.goal(.reading, count: 2)],
            events: [], existingMargins: [], baseRules: [], notBefore: now
        )

        XCTAssertEqual(proposal.slots.count, 5, "The remaining half-month has enough room for these goals")
        XCTAssertTrue(proposal.slots.allSatisfy { $0.startDate >= now })
        XCTAssertTrue(proposal.slots.allSatisfy { MonthKey(date: TestFixtures.september).interval.contains($0.startDate) })
        XCTAssertTrue(proposal.unmetGoals.isEmpty)
    }

    func testEntirePastMonthReportsUnmetGoalsInsteadOfBackfilling() {
        let now = TestFixtures.date(2026, 10, 1, 0)
        let proposal = SchedulerEngine(calendar: .mira).propose(
            month: TestFixtures.september,
            goals: [TestFixtures.goal(.rest, count: 2), TestFixtures.goal(.reading, count: 1)],
            events: [], existingMargins: [], baseRules: [], notBefore: now
        )

        XCTAssertTrue(proposal.slots.isEmpty)
        XCTAssertEqual(proposal.unmetGoals, [.rest: 2, .reading: 1])
    }

    func testCutoffIncludesAStartingNowSlotButExcludesOneAlreadyInProgress() {
        let engine = SchedulerEngine(calendar: .mira)
        let start = TestFixtures.date(day: 30, hour: 18)
        let goal = TestFixtures.goal(.rest, count: 1)
        let atStart = engine.propose(
            month: TestFixtures.september, goals: [goal], events: [],
            existingMargins: [], baseRules: [], notBefore: start
        )
        XCTAssertEqual(atStart.slots.map(\.startDate), [start])

        let alreadyStarted = engine.propose(
            month: TestFixtures.september, goals: [goal], events: [],
            existingMargins: [], baseRules: [], notBefore: start.addingTimeInterval(60)
        )
        XCTAssertTrue(alreadyStarted.slots.isEmpty)
        XCTAssertEqual(alreadyStarted.unmetGoals[.rest], 1)
    }

    func testRelocationSuggestionsAlsoStayAfterTheCurrentTime() {
        let now = TestFixtures.date(day: 21, hour: 20)
        let margin = TestFixtures.event(day: 10, hour: 9, duration: 12, kind: .margin, marginKind: .rest)
        let engine = SchedulerEngine(calendar: .mira)
        let suggestions = engine.relocationCandidates(
            for: margin, month: TestFixtures.september, events: [], otherMargins: [],
            baseRules: [], limit: 10, notBefore: now
        )
        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertTrue(suggestions.allSatisfy { $0 >= now })
        XCTAssertTrue(engine.relocationCandidates(
            for: margin, month: TestFixtures.september, events: [], otherMargins: [],
            baseRules: [], notBefore: TestFixtures.date(2026, 10, 1, 0)
        ).isEmpty)
    }

    func testRelocationPreservesExactDurationAndBuffers() {
        var margin = TestFixtures.event(day: 10, duration: 1, kind: .margin, marginKind: .reading)
        margin.endDate = margin.startDate.addingTimeInterval(90 * 60)
        let candidate = TestFixtures.date(day: 30, hour: 18)
        var laterEvent = TestFixtures.event(day: 30, hour: 20, duration: 1)
        laterEvent.startDate = candidate.addingTimeInterval(100 * 60)
        let scheduler = SchedulerEngine(calendar: .mira)
        let suggestions = scheduler.relocationCandidates(
            for: margin, month: TestFixtures.september, events: [laterEvent], otherMargins: [],
            baseRules: [], notBefore: candidate
        )
        XCTAssertEqual(suggestions, [candidate], "A 90-minute margin fits before the 19:40 event")
        margin.bufferAfterMinutes = 20
        XCTAssertTrue(scheduler.relocationCandidates(
            for: margin, month: TestFixtures.september, events: [laterEvent], otherMargins: [],
            baseRules: [], notBefore: candidate
        ).isEmpty, "Its recovery buffer must fit as well")
    }

    func testOvernightRelocationChecksNextDayRulesAndMonthBoundary() {
        let margin = TestFixtures.event(day: 10, hour: 9, duration: 12, kind: .margin, marginKind: .rest)
        let scheduler = SchedulerEngine(calendar: .mira)
        let evening = TestFixtures.date(day: 29, hour: 18)
        let suggestions = scheduler.relocationCandidates(
            for: margin, month: TestFixtures.september, events: [], otherMargins: [],
            baseRules: [BaseAvailabilityRule(weekday: 4, startMinute: 0, endMinute: 6 * 60)],
            limit: 62, notBefore: evening
        )
        XCTAssertFalse(suggestions.contains(evening), "The overnight interval overlaps Wednesday's base rule")
        XCTAssertTrue(scheduler.relocationCandidates(
            for: margin, month: TestFixtures.september, events: [], otherMargins: [],
            baseRules: [], notBefore: TestFixtures.date(day: 30, hour: 18)
        ).isEmpty, "Moving a twelve-hour margin must not silently shorten it at month-end")
    }

    func testRebalanceOnlyMovesFutureMarginsAndKeepsTheirExactDuration() throws {
        let past = TestFixtures.event(day: 5, hour: 9, duration: 2, kind: .margin, marginKind: .reading)
        var future = TestFixtures.event(day: 25, hour: 9, duration: 2, kind: .margin, marginKind: .reading)
        future.endDate = future.startDate.addingTimeInterval(90 * 60)
        let events = [TestFixtures.event(day: 5, load: .heavy), TestFixtures.event(day: 25, load: .heavy)]
        let proposal = try XCTUnwrap(RebalanceEngine(calendar: .mira).propose(
            month: TestFixtures.september, items: [past, future] + events, goals: [], baseRules: [],
            scheduler: SchedulerEngine(calendar: .mira), notBefore: TestFixtures.date(day: 21)
        ))
        XCTAssertEqual(proposal.moves.map(\.marginItemID), [future.id])
        XCTAssertEqual(proposal.moves.first?.durationSeconds, 90 * 60)
        XCTAssertTrue(proposal.moves.allSatisfy { $0.to >= TestFixtures.date(day: 21) })
    }

    func testRebalanceReservesEachAdditionBeforeChoosingAnother() throws {
        let cutoff = TestFixtures.date(day: 26, hour: 12)
        let proposal = try XCTUnwrap(RebalanceEngine(calendar: .mira).propose(
            month: TestFixtures.september, items: [],
            goals: [TestFixtures.goal(.reading, count: 2), TestFixtures.goal(.personalProject, count: 2)],
            baseRules: [], scheduler: SchedulerEngine(calendar: .mira), notBefore: cutoff
        ))
        XCTAssertEqual(proposal.moves.count, 4)
        let intervals = try proposal.moves.map { move -> DateInterval in
            XCTAssertGreaterThanOrEqual(move.to, cutoff)
            let duration = try XCTUnwrap(move.durationSeconds)
            XCTAssertGreaterThan(duration, 0)
            return DateInterval(start: move.to, duration: duration)
        }
        for first in intervals.indices {
            for second in intervals.indices where second > first {
                XCTAssertFalse(intervals[first].intersects(intervals[second]))
            }
        }
        XCTAssertNil(RebalanceEngine(calendar: .mira).propose(
            month: TestFixtures.september, items: [], goals: [TestFixtures.goal(.reading, count: 2)],
            baseRules: [], scheduler: SchedulerEngine(calendar: .mira), notBefore: TestFixtures.date(2026, 10, 1, 0)
        ))
    }

    func testRebalanceFingerprintDetectsElapsedTimeRulesAndGoalDuration() throws {
        let engine = RebalanceEngine(calendar: .mira)
        let scheduler = SchedulerEngine(calendar: .mira)
        var goal = TestFixtures.goal(.reading, count: 2)
        let cutoff = TestFixtures.date(day: 20)
        func make(_ goals: [MarginGoalSnapshot], rules: [BaseAvailabilityRule] = [], now: Date) throws -> RebalanceProposal {
            try XCTUnwrap(engine.propose(month: TestFixtures.september, items: [], goals: goals,
                                        baseRules: rules, scheduler: scheduler, notBefore: now))
        }
        let reviewed = try make([goal], now: cutoff)
        XCTAssertTrue(engine.matches(reviewed, try make([goal], now: cutoff), items: []), "Generated UUIDs must not invalidate an unchanged plan")
        let earliest = try XCTUnwrap(reviewed.moves.map(\.to).min())
        XCTAssertFalse(engine.matches(reviewed, try make([goal], now: earliest.addingTimeInterval(1)), items: []))
        XCTAssertNotEqual(reviewed.stateHash, try make([goal], rules: [BaseAvailabilityRule(weekday: 1, startMinute: 0, endMinute: 60)], now: cutoff).stateHash)
        goal.durationHours += 1
        XCTAssertNotEqual(reviewed.stateHash, try make([goal], now: cutoff).stateHash)
        var edited = reviewed
        edited.moves[0].to = edited.moves[0].to.addingTimeInterval(3600)
        XCTAssertFalse(engine.matches(reviewed, edited, items: []), "An unchanged hash cannot authorize edited move contents")
    }
}
