import XCTest
@testable import Mira

final class ProposalTimelineTests: XCTestCase {
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
