import XCTest
@testable import Mira

final class SchedulerEngineTests: XCTestCase {
    func testProposalAvoidsEventsAndBaseRules() {
        let engine = SchedulerEngine(calendar: .mira)
        let events = [
            TestFixtures.event(title: "一日予定", day: 5, hour: 9, duration: 12, load: .heavy)
        ]
        let baseRules = (2...6).map { BaseAvailabilityRule(weekday: $0, startMinute: 9 * 60, endMinute: 18 * 60) }

        let proposal = engine.propose(
            month: TestFixtures.september,
            goals: [TestFixtures.goal(.rest, count: 2), TestFixtures.goal(.reading, count: 1)],
            events: events,
            existingMargins: [],
            baseRules: baseRules
        )

        XCTAssertEqual(proposal.slots.count, 3)
        for slot in proposal.slots {
            XCTAssertFalse(events.contains { $0.occupiedInterval.intersects(slot.occupiedInterval) })
            if slot.marginKind == .reading {
                let weekday = Calendar.mira.component(.weekday, from: slot.startDate)
                let hour = Calendar.mira.component(.hour, from: slot.startDate)
                XCTAssertTrue(weekday == 1 || weekday == 7 || hour >= 18)
            }
        }
    }

    func testProposalIsDeterministicByDateAndKind() {
        let engine = SchedulerEngine(calendar: .mira)
        let goals = [TestFixtures.goal(.rest, count: 3), TestFixtures.goal(.solo, count: 2)]
        let first = engine.propose(month: TestFixtures.september, goals: goals, events: [], existingMargins: [], baseRules: [])
        let second = engine.propose(month: TestFixtures.september, goals: goals, events: [], existingMargins: [], baseRules: [])

        let firstSignature = first.slots.map { "\($0.marginKind?.rawValue ?? "none")|\($0.startDate.timeIntervalSince1970)" }
        let secondSignature = second.slots.map { "\($0.marginKind?.rawValue ?? "none")|\($0.startDate.timeIntervalSince1970)" }
        XCTAssertEqual(firstSignature, secondSignature)
    }

    func testUnmetGoalIsReported() {
        let engine = SchedulerEngine(calendar: .mira)
        let allDaysBlocked = (1...30).map {
            TestFixtures.event(title: "終日", day: $0, hour: 0, duration: 24, load: .heavy)
        }
        let proposal = engine.propose(
            month: TestFixtures.september,
            goals: [TestFixtures.goal(.rest, count: 4)],
            events: allDaysBlocked,
            existingMargins: [],
            baseRules: []
        )
        XCTAssertEqual(proposal.unmetGoals[.rest], 4)
    }

    func testRestFallsBackToWeekdayEveningWhenWeekendsAreBusy() {
        let engine = SchedulerEngine(calendar: .mira)
        let calendar = Calendar.mira
        let weekendEvents = (1...30).compactMap { day -> CalendarItemSnapshot? in
            let date = TestFixtures.date(day: day, hour: 0)
            let weekday = calendar.component(.weekday, from: date)
            guard weekday == 1 || weekday == 7 else { return nil }
            return TestFixtures.event(title: "週末の予定", day: day, hour: 0, duration: 24, load: .heavy)
        }
        let baseRules = (2...6).map {
            BaseAvailabilityRule(weekday: $0, startMinute: 9 * 60, endMinute: 18 * 60)
        }

        let proposal = engine.propose(
            month: TestFixtures.september,
            goals: [TestFixtures.goal(.rest, count: 2)],
            events: weekendEvents,
            existingMargins: [],
            baseRules: baseRules
        )

        XCTAssertEqual(proposal.slots.count, 2)
        XCTAssertTrue(proposal.slots.allSatisfy { !$0.isAllDay })
        XCTAssertTrue(proposal.slots.allSatisfy { calendar.component(.hour, from: $0.startDate) == 18 })
    }
}
