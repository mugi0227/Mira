import Foundation
import SwiftData
import XCTest
@testable import Mira

@MainActor
final class DraftPersistenceTests: XCTestCase {
    func testArchiveRoundTripKeepsRawInputAndSelectedCandidateIdentities() throws {
        let storage = DraftStorage()
        let first = CandidateRecommendation(day: TestFixtures.date(day: 12), timeBand: .evening, durationBucket: .short, score: 90)
        let second = CandidateRecommendation(day: TestFixtures.date(day: 13), timeBand: .midday, durationBucket: .short, score: 80)
        let draft = SchedulingDraft(
            title: "友達とご飯", person: "あき", month: TestFixtures.september,
            dateRangeStart: TestFixtures.date(day: 1), dateRangeEnd: TestFixtures.date(day: 30),
            durationBucket: .short, timeBands: [.midday, .evening], inferredFields: ["duration"],
            recommendations: [first, second], selectedRecommendationIDs: [second.id],
            detailedTimeEnabled: true, detailedStartHour: 18, detailedStartMinute: 30
        )
        let archive = DraftArchive(quickInputText: "来月の土曜、まだ迷っている", drafts: [
            SavedMiraDraft(content: .scheduling(draft, .checkInvitation), updatedAt: TestFixtures.september)
        ])

        try storage.save(archive)
        let loaded = try storage.load()

        XCTAssertFalse(loaded.recoveredCorruption)
        XCTAssertEqual(loaded.archive, archive)
        guard case .scheduling(let restored, let intent) = loaded.archive.drafts[0].content else {
            return XCTFail("Expected the original scheduling draft")
        }
        XCTAssertEqual(intent, .checkInvitation)
        XCTAssertEqual(restored.selectedRecommendations.map(\.id), [second.id])
        XCTAssertEqual(restored.detailedStartMinute, 30)
    }

    func testEventFormAndPreviewsRoundTripWithoutChangingTheCalendar() throws {
        let storage = DraftStorage()
        var form = ManualEventDraft(date: TestFixtures.date(day: 12), isMargin: true)
        form.title = "読みかけの本"
        form.marginKind = .reading
        form.isAllDay = true
        form.isImportant = true
        let event = TestFixtures.event(title: "ご飯", day: 13)
        let preview = EventCreationPreview(caseID: UUID(), event: event, conflicts: ["休息と重なります"], impact: .none)
        let change = ChangePreview(caseID: UUID(), itemID: event.id, title: event.title, before: event, after: event, conflicts: [], impact: .none)
        let question = ConversationClarification(caseID: UUID(), question: "どの時間帯？", options: ["昼", "夜"], originalText: "来週ご飯")
        let content: [SavedDraftContent] = [
            .eventForm(form), .eventPreview(preview), .change(change),
            .clarification(question, .unknown(question.originalText))
        ]
        let archive = DraftArchive(drafts: content.map { SavedMiraDraft(content: $0, updatedAt: TestFixtures.september) })

        try storage.save(archive)
        XCTAssertEqual(try storage.load().archive, archive)
    }

    func testClosingDraftKeepsItAcrossStoreRecreationUntilExplicitlyDiscarded() throws {
        let storage = DraftStorage()
        let store = try makeStore(storage: storage)
        let draft = SchedulingDraft(
            title: "映画", month: TestFixtures.september,
            dateRangeStart: TestFixtures.date(day: 1), dateRangeEnd: TestFixtures.date(day: 30),
            durationBucket: .halfDay, timeBands: [.secondHalf]
        )
        store.activeSchedulingIntent = .checkInvitation
        store.activeSchedulingDraft = draft
        store.activeSchedulingDraft?.title = "映画とご飯"
        store.activeSchedulingDraft = nil

        let reopened = try makeStore(storage: storage)
        reopened.loadDrafts()
        XCTAssertNil(reopened.activeSchedulingDraft, "Startup must not unexpectedly open a modal")
        XCTAssertEqual(reopened.savedDrafts.count, 1)
        reopened.resumeSavedDraft(id: draft.id)
        XCTAssertEqual(reopened.activeSchedulingDraft?.title, "映画とご飯")
        XCTAssertEqual(reopened.activeSchedulingIntent, .checkInvitation)

        reopened.discardSavedDraft(id: draft.id)
        XCTAssertNil(reopened.activeSchedulingDraft)
        XCTAssertTrue(try storage.load().archive.drafts.isEmpty)
    }

    func testFileArchiveSurvivesStorageRecreationWithOnboardingProgress() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("mira-draft-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("drafts.json")
        let onboarding = OnboardingDraft(
            step: 5, selections: [.rest, .reading], targets: [.rest: 4, .reading: 2], automatic: true,
            comfort: .high, rules: [.init(weekday: 2, isEnabled: true, startMinute: 540, endMinute: 1080)],
            weekStartDay: .sunday, useDeviceHolidays: false, quickStart: true
        )
        let archive = DraftArchive(quickInputText: "金曜の誘いを保留したい", onboarding: onboarding)
        try DraftStorage(fileURL: url).save(archive)
        XCTAssertEqual(try DraftStorage(fileURL: url).load().archive, archive)
    }

    func testRegeneratingReplyReplacesOnlyThatCasesDraft() throws {
        let store = try makeStore(storage: DraftStorage())
        let caseID = UUID()
        let original = DeclineDraft(caseID: caseID, title: "食事", person: nil, text: "今回は見送るね", tone: "親しみ", audience: .friend, generationIndex: 0)
        var replacement = original
        replacement.id = UUID()
        replacement.text = "誘ってくれてありがとう。今回は難しいです"
        replacement.generationIndex = 1
        store.activeDeclineDraft = original
        store.activeDeclineDraft = replacement
        XCTAssertEqual(store.savedDrafts.count, 1)
        XCTAssertEqual(store.savedDrafts.first?.id, replacement.id)
    }

    func testCorruptArchiveFallsBackAndPreservesRecoveryBytes() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("mira-draft-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("drafts.json")
        let broken = Data("{unfinished".utf8)
        try broken.write(to: url)

        let loaded = try DraftStorage(fileURL: url).load()
        XCTAssertTrue(loaded.recoveredCorruption)
        XCTAssertEqual(loaded.archive, .empty)
        let recovery = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .first { $0.lastPathComponent.hasPrefix("drafts-recovery-") }
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(recovery)), broken)
    }

    func testWriteFailureKeepsDraftInMemoryAndReportsFailure() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("mira-draft-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        // A directory cannot be atomically replaced by a JSON file.
        let store = try makeStore(storage: DraftStorage(fileURL: directory))
        let form = ManualEventDraft(date: TestFixtures.september)
        store.saveDraft(.eventForm(form))
        XCTAssertEqual(store.savedDrafts.first?.id, form.id)
        XCTAssertNotNil(store.draftPersistenceIssue)
        XCTAssertFalse(store.persistDraftArchive())
    }

    private func makeStore(storage: DraftStorage) throws -> MiraStore {
        let schema = Schema([
            AppSettingsEntity.self, CalendarItemEntity.self, MarginGoalEntity.self,
            BaseRuleEntity.self, AdjustmentEntity.self, PendingInvitationEntity.self,
            LoadRuleEntity.self, ImportantPersonEntity.self, ConversationCaseEntity.self,
            RebalanceProposalEntity.self
        ])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return MiraStore(container: container, draftStorage: storage)
    }
}
