import Foundation
import SwiftData
import XCTest
@testable import Mira

final class ChatAnswerTests: XCTestCase {
    func testMarkdownRendersBoldBulletsAndLineBreaks() {
        let result = ChatAnswer.markdown("**概要**\n* **読書**\n- 休息")
        XCTAssertEqual(String(result.characters), "概要\n• 読書\n• 休息")
        XCTAssertTrue(result.runs.contains { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true })
    }

    func testEmptyAndUnfinishedMarkdown() {
        XCTAssertEqual(String(ChatAnswer.markdown("").characters), "")
        XCTAssertFalse(String(ChatAnswer.markdown("**途中").characters).contains("**"))
    }

    func testTrimKeepsShortAnswerAndLimitsRepeatedLongAnswer() {
        XCTAssertEqual(ChatAnswer.trimmed("短いにゃ。"), "短いにゃ。")
        XCTAssertEqual(ChatAnswer.trimmed(""), "")
        XCTAssertEqual(ChatAnswer.trimmed("まとめ\n休もう。\nまとめ\n休もう。"), "まとめ\n休もう。")
        XCTAssertEqual(ChatAnswer.trimmed(String(repeating: "長", count: 1000)).count, ChatAnswer.characterLimit)
        XCTAssertEqual(ChatAnswer.trimmed((1...10).map { "項目\($0)" }.joined(separator: "\n")).components(separatedBy: "\n").count, ChatAnswer.lineLimit)
        let eightLines = (1...8).map { "項目\($0)" }.joined(separator: "\n")
        XCTAssertEqual(ChatAnswer.trimmed("\n" + eightLines.replacingOccurrences(of: "\n", with: "\n\n") + "\n"), eightLines)
        let fullAnswer = String(repeating: "根拠", count: 200)
        XCTAssertEqual(ChatAnswer.trimmed(fullAnswer), fullAnswer)
    }

    @MainActor
    func testToolOutputIncludesJapaneseWeekdayAndRange() throws {
        let schema = Schema([AppSettingsEntity.self, CalendarItemEntity.self, MarginGoalEntity.self,
            BaseRuleEntity.self, AdjustmentEntity.self, PendingInvitationEntity.self,
            LoadRuleEntity.self, ImportantPersonEntity.self, ConversationCaseEntity.self,
            RebalanceProposalEntity.self])
        let container = try ModelContainer(for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let store = MiraStore(container: container,
            classifier: RuleBasedSemanticClassifier(), conversationInterpreter: RuleBasedConversationInterpreter())
        let start = Calendar.mira.date(from: DateComponents(year: 2026, month: 11, day: 28))!
        let end = start.addingDays(4)
        let summary = store.toolListSchedule(from: start, to: end).summary
        XCTAssertTrue(summary.contains("2026年11月28日（土曜日）"))
        XCTAssertTrue(summary.contains("2026年12月1日（火曜日）"))
        XCTAssertFalse(summary.contains("12月2日"))
        XCTAssertTrue(store.toolMonthBalance(month: start).summary.contains("2026年11月30日（月曜日）"))
    }
}
