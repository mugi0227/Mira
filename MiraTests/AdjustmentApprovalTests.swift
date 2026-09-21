import SwiftData
import XCTest
@testable import Mira

@MainActor
final class AdjustmentApprovalTests: XCTestCase {
    func testInvalidDatesAndDuplicateIDsDoNotMutateExistingCalendar() throws {
        let store = try makeStore()
        let existing = TestFixtures.event(title: "保存済み", day: 10)
        store.context.insert(CalendarItemEntity(snapshot: existing))
        try store.context.save()
        try store.refresh()
        var duplicate = existing
        duplicate.title = "上書きしない"
        XCTAssertFalse(store.commitAdvisedEvent(duplicate, impact: .none, resolution: .exception))
        var invalid = TestFixtures.event(day: 11)
        invalid.endDate = invalid.startDate
        XCTAssertFalse(store.commitAdvisedEvent(invalid, impact: .none, resolution: .exception))
        XCTAssertEqual(store.items, [existing])
    }

    func testOverlappingLastMarginStaysIntactUntilApprovalThenCanBeConsumed() async throws {
        let store = try makeStore()
        let margin = TestFixtures.event(day: 10, hour: 9, duration: 12, kind: .margin, marginKind: .rest)
        let existing = TestFixtures.event(title: "すでにある予定", day: 10, hour: 18)
        store.context.insert(CalendarItemEntity(snapshot: margin))
        store.context.insert(CalendarItemEntity(snapshot: existing))
        store.context.insert(MarginGoalEntity(snapshot: TestFixtures.goal(.rest, count: 1)))
        let session = makeAdjustment(store)
        try store.context.save()
        try store.refresh()
        let candidate = try XCTUnwrap(session.candidates.first)

        let unapproved = await store.confirmCandidate(sessionID: session.id, candidateID: candidate.id)
        XCTAssertFalse(unapproved)
        let preparedReview = await store.prepareCandidateConfirmation(sessionID: session.id, candidateID: candidate.id)
        let review = try XCTUnwrap(preparedReview)
        XCTAssertTrue(review.conflicts.contains("確定予定と重なっています"))
        XCTAssertEqual(review.impact.protectionLevel, .finalDefense)
        XCTAssertEqual(session.status, .draft)
        XCTAssertTrue(session.candidates.allSatisfy { $0.status == .held })
        XCTAssertTrue(store.items.contains { $0.id == margin.id })

        let saved = await store.confirmCandidate(sessionID: session.id, candidateID: candidate.id, approval: review)
        XCTAssertTrue(saved)
        XCTAssertEqual(session.status, .confirmed)
        XCTAssertTrue(store.items.contains { $0.id == existing.id })
        XCTAssertTrue(store.items.contains { $0.id == review.event.id })
        XCTAssertFalse(store.items.contains { $0.id == margin.id })
        XCTAssertEqual(session.candidates.filter { $0.status == .confirmed }.count, 1)
        XCTAssertEqual(session.candidates.filter { $0.status == .released }.count, 1)

        let duplicate = await store.confirmCandidate(sessionID: session.id, candidateID: candidate.id, approval: review)
        XCTAssertFalse(duplicate)
        XCTAssertEqual(store.items.filter { $0.id == review.event.id }.count, 1)
    }

    func testCalendarChangeRequiresFreshReviewWithoutReleasingCandidates() async throws {
        let store = try makeStore()
        let session = makeAdjustment(store)
        try store.context.save()
        try store.refresh()
        let candidate = try XCTUnwrap(session.candidates.first)
        let firstReview = await store.prepareCandidateConfirmation(sessionID: session.id, candidateID: candidate.id)
        let oldReview = try XCTUnwrap(firstReview)
        XCTAssertFalse(oldReview.conflicts.contains("別の日程調整でも候補になっています"), "Own held candidates must not warn about themselves")

        store.context.insert(CalendarItemEntity(snapshot: TestFixtures.event(day: 10, hour: 18)))
        try store.context.save()
        let saved = await store.confirmCandidate(sessionID: session.id, candidateID: candidate.id, approval: oldReview)
        XCTAssertFalse(saved)
        XCTAssertEqual(session.status, .draft)
        XCTAssertTrue(session.candidates.allSatisfy { $0.status == .held })

        let refreshedReview = await store.prepareCandidateConfirmation(sessionID: session.id, candidateID: candidate.id)
        let newReview = try XCTUnwrap(refreshedReview)
        XCTAssertTrue(newReview.conflicts.contains("確定予定と重なっています"))
        let approved = await store.confirmCandidate(sessionID: session.id, candidateID: candidate.id, approval: newReview)
        XCTAssertTrue(approved)
    }

    func testSavingCandidatesDoesNotClaimTheyWereSent() async throws {
        let store = try makeStore()
        store.createAdjustment(title: "オンライン相談", contact: "友人", dates: [TestFixtures.date(day: 10)], timeOfDay: .evening, deadline: nil)
        let session = try XCTUnwrap(store.adjustments.first)
        XCTAssertEqual(session.status, .draft)
        let sent = await store.markAdjustmentSent(session)
        XCTAssertTrue(sent)
        XCTAssertEqual(session.status, .waiting)
        let unsent = await store.markAdjustmentUnsent(session)
        XCTAssertTrue(unsent)
        XCTAssertEqual(session.status, .draft)
    }

    func testInvitationRechecksChangesAndStillAllowsApprovedOverlap() async throws {
        let store = try makeStore()
        store.createPendingInvitation(title: "オンライン相談", contact: "友人", candidateDate: TestFixtures.date(day: 10), timeOfDay: .evening, deadline: nil)
        let invitation = try XCTUnwrap(store.pendingInvitations.first)
        let candidate = try XCTUnwrap(invitation.candidates.first)
        let event = await store.prepareEvent(title: invitation.title, startDate: candidate.startDate, endDate: candidate.endDate, isAllDay: false, isImportant: false)
        let oldContext = store.scheduleReviewContext()
        let existing = TestFixtures.event(day: 10, hour: 18)
        store.context.insert(CalendarItemEntity(snapshot: existing))
        try store.context.save()

        XCTAssertFalse(store.acceptPending(invitation, approvedEvent: event, reviewContext: oldContext, resolution: .exception))
        XCTAssertEqual(invitation.status, .considering)
        XCTAssertFalse(store.items.contains { $0.id == event.id })

        let context = store.scheduleReviewContext()
        XCTAssertTrue(store.eventEntryConflicts(for: event).contains("確定予定と重なっています"))
        XCTAssertTrue(store.acceptPending(invitation, approvedEvent: event, reviewContext: context, resolution: .exception))
        XCTAssertEqual(invitation.status, .accepted)
        XCTAssertTrue(store.items.contains { $0.id == event.id })
        XCTAssertTrue(store.items.contains { $0.id == existing.id })
    }

    private func makeAdjustment(_ store: MiraStore) -> AdjustmentEntity {
        let session = AdjustmentEntity(
            title: "オンライン相談", status: .draft,
            candidates: [10, 12].map {
                CandidateSlotSnapshot(startDate: TestFixtures.date(day: $0, hour: 18), endDate: TestFixtures.date(day: $0, hour: 20), timeOfDay: .evening)
            }, generatedMessage: "候補日の相談です"
        )
        store.context.insert(session)
        return session
    }

    private func makeStore() throws -> MiraStore {
        let schema = Schema([
            AppSettingsEntity.self, CalendarItemEntity.self, MarginGoalEntity.self,
            BaseRuleEntity.self, AdjustmentEntity.self, PendingInvitationEntity.self,
            LoadRuleEntity.self, ImportantPersonEntity.self, ConversationCaseEntity.self,
            RebalanceProposalEntity.self
        ])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return MiraStore(container: container, classifier: RuleBasedSemanticClassifier())
    }
}
