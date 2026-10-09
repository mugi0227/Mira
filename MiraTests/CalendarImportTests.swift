import Foundation
import SwiftData
import XCTest
@testable import Mira

final class CalendarImportParsingTests: XCTestCase {
    func testGeminiResponseBecomesDatedCandidates() throws {
        let inner = """
        {"events":[
          {"title":"testで追加しています","date":"2026-10-10","startTime":"01:00","endTime":"02:00","allDay":false,"confidence":0.95},
          {"title":"鳥羽旅行","date":"2026-09-12","endDate":"2026-09-13","allDay":true},
          {"title":"有馬記念","date":"2026-12-27","startTime":"15:40","allDay":false,"confidence":0.4},
          {"title":"","date":"2026-10-11","allDay":true}
        ]}
        """
        let envelope: [String: Any] = ["candidates": [["content": ["parts": [["text": inner]]]]]]
        let data = try JSONSerialization.data(withJSONObject: envelope)

        let page = try GeminiCalendarExtractor.page(fromResponse: data)
        let candidates = ImportCandidateBuilder.candidates(from: page, sourceIndex: 0)
        XCTAssertEqual(candidates.count, 3, "blank titles are dropped")

        let timed = candidates[0]
        XCTAssertEqual(Calendar.mira.component(.hour, from: timed.start), 1)
        XCTAssertEqual(timed.end.timeIntervalSince(timed.start), 3600)
        XCTAssertFalse(timed.isAllDay)
        XCTAssertEqual(timed.colorTag, .other, "unknown titles default to その他")

        let trip = candidates[1]
        XCTAssertTrue(trip.isAllDay)
        XCTAssertEqual(trip.end.timeIntervalSince(trip.start), 2 * 86_400, "both days are covered")
        XCTAssertEqual(trip.colorTag, .play)

        let race = candidates[2]
        XCTAssertEqual(race.colorTag, .keiba)
        XCTAssertTrue(race.needsReview, "low confidence asks for a look")
        XCTAssertEqual(race.end.timeIntervalSince(race.start), 3600)
    }

    func testTimeParsingAcceptsJapaneseForms() {
        XCTAssertEqual(ImportCandidateBuilder.minutes(from: "9:05"), 545)
        XCTAssertEqual(ImportCandidateBuilder.minutes(from: "19時"), 1140)
        XCTAssertEqual(ImportCandidateBuilder.minutes(from: "19時30分"), 1170)
        XCTAssertNil(ImportCandidateBuilder.minutes(from: ""))
        XCTAssertNil(ImportCandidateBuilder.minutes(from: "25:00"))
    }

    func testDuplicatesAgainstCalendarAndAcrossScreenshotsStartUnselected() {
        let existing = TestFixtures.event(title: "歯医者", day: 10, hour: 18)
        let make = { (title: String, day: Int) in
            ImportCandidate(title: title, start: TestFixtures.date(day: day, hour: 18),
                end: TestFixtures.date(day: day, hour: 19), isAllDay: false, colorTag: nil,
                confidence: 0.9, sourceIndex: 0)
        }
        let marked = ImportCandidateBuilder.markDuplicates(
            [make("歯医者", 10), make("カフェ", 11), make("カフェ", 11), make("カフェ", 12)],
            existing: [existing]
        )
        XCTAssertEqual(marked.map(\.isSelected), [false, true, false, true])
        XCTAssertEqual(marked[0].duplicateOf, "歯医者")
    }

    func testRequestAsksForSchemaShapedJSON() {
        let body = GeminiCalendarExtractor.body(image: Data([0xFF, 0xD8]), today: TestFixtures.date(day: 1))
        let config = body["generationConfig"] as? [String: Any]
        XCTAssertEqual(config?["responseMimeType"] as? String, "application/json")
        XCTAssertNotNil(config?["responseSchema"])
    }
}

@MainActor
final class CalendarImportCommitTests: XCTestCase {
    func testImportAddsOnlySelectedPlansAndUndoesAsOne() async throws {
        let schema = Schema([
            AppSettingsEntity.self, CalendarItemEntity.self, MarginGoalEntity.self,
            BaseRuleEntity.self, AdjustmentEntity.self, PendingInvitationEntity.self,
            LoadRuleEntity.self, ImportantPersonEntity.self, ConversationCaseEntity.self,
            RebalanceProposalEntity.self
        ])
        let container = try ModelContainer(for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let store = MiraStore(container: container, classifier: RuleBasedSemanticClassifier(),
            conversationInterpreter: RuleBasedConversationInterpreter(), draftStorage: DraftStorage())
        var skipped = ImportCandidate(title: "スキップ", start: TestFixtures.date(day: 5, hour: 10),
            end: TestFixtures.date(day: 5, hour: 11), isAllDay: false, colorTag: nil, confidence: 0.9, sourceIndex: 0)
        skipped.isSelected = false
        let kept = ImportCandidate(title: "推しのライブ", start: TestFixtures.date(day: 6, hour: 18),
            end: TestFixtures.date(day: 6, hour: 21), isAllDay: false, colorTag: .otaku, confidence: 0.9, sourceIndex: 0)

        XCTAssertEqual(store.importCandidates([skipped, kept]), 1)
        XCTAssertEqual(store.items.map(\.title), ["推しのライブ"])
        XCTAssertEqual(store.items.first?.colorTag, .otaku)
        XCTAssertEqual(store.undoEntry?.title, "カレンダーの引っ越し")

        await store.undoLastCalendarMutation()
        XCTAssertTrue(store.items.isEmpty)
    }
}
