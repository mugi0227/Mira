import XCTest
@testable import Mira

final class ProposalTimelineTests: XCTestCase {
    func testScrollStartsBeforeEarliestConflictAndClampsAtMidnight() {
        let event = TestFixtures.event(title: "追加", day: 12, hour: 10)
        let conflict = ConflictEngine.Detail(start: TestFixtures.date(day: 12, hour: 9), text: "仕事")
        XCTAssertEqual(ProposalTimeline.scrollHour(for: DayTimelineProposal(event: event, conflicts: [conflict]), on: event.startDate), 8)
        XCTAssertEqual(ProposalTimeline.scrollHour(for: DayTimelineProposal(event: event, conflicts: []), on: event.startDate), 9)
        let earlier = ConflictEngine.Detail(start: TestFixtures.date(day: 11, hour: 23), text: "夜")
        XCTAssertEqual(ProposalTimeline.scrollHour(for: DayTimelineProposal(event: event, conflicts: [earlier]), on: event.startDate), 0)
    }

    func testBaseRuleDetailsExposeTheWholeBand() {
        let start = TestFixtures.date(day: 12, hour: 10)
        let candidate = CandidateSlotSnapshot(startDate: start, endDate: start.addingTimeInterval(3600), timeOfDay: .morning)
        let rule = BaseAvailabilityRule(weekday: Calendar.mira.component(.weekday, from: start), startMinute: 540, endMinute: 1080)
        let detail = ConflictEngine().conflictDetailEntries(candidate: candidate, events: [], otherCandidates: [], baseRules: [rule]).first
        XCTAssertEqual(detail?.baseRuleInterval, DateInterval(start: TestFixtures.date(day: 12, hour: 9), end: TestFixtures.date(day: 12, hour: 18)))
        XCTAssertNil(detail?.itemID)
    }

    func testOverlapClipsToSharedInterval() {
        let start = TestFixtures.date(day: 12, hour: 10)
        let end = TestFixtures.date(day: 12, hour: 12)
        let proposal = DateInterval(start: start, end: end)
        let existing = DateInterval(start: start.addingTimeInterval(-3600), end: end.addingTimeInterval(-3600))
        XCTAssertEqual(ProposalTimeline.overlap(proposal, existing), DateInterval(start: start, end: end.addingTimeInterval(-3600)))
        XCTAssertEqual(ProposalTimeline.overlap(proposal, proposal), proposal)
        XCTAssertNil(ProposalTimeline.overlap(proposal, DateInterval(start: end, duration: 3600)))
        XCTAssertNil(ProposalTimeline.overlap(proposal, DateInterval(start: start, duration: 0)))
    }

    func testSelectionExcludesSelfAndDisjointItems() {
        let proposal = TestFixtures.event(title: "追加", day: 12, hour: 10, duration: 2)
        let work = TestFixtures.event(title: "仕事", day: 12, hour: 9, duration: 3)
        let later = TestFixtures.event(title: "後", day: 12, hour: 12)
        XCTAssertEqual(ProposalTimeline.overlappingItems([proposal, work, later], proposal: proposal).map(\.id), [work.id])
        XCTAssertTrue(ProposalTimeline.overlappingItems([], proposal: proposal).isEmpty)
    }

    func testConflictEntriesKeepItemIdentityAndTentativeTime() {
        var event = TestFixtures.event(title: "食事", day: 12, hour: 19)
        event.exactTimeKnown = false
        event.schedulingTimeBand = .evening
        let candidate = CandidateSlotSnapshot(startDate: event.startDate, endDate: event.endDate, timeOfDay: .evening)
        let details = ConflictEngine().conflictDetailEntries(candidate: candidate, events: [event], otherCandidates: [])
        XCTAssertEqual(details.first?.itemID, event.id)
        XCTAssertTrue(details.first?.text.contains("夜・時間未定") == true)
    }
}
