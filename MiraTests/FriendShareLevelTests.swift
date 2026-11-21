import SwiftData
import SwiftUI
import XCTest
@testable import Mira

@MainActor
final class FriendShareLevelTests: XCTestCase {
    func testLevels() {
        let day = TestFixtures.date(day: 2)
        let items = [TestFixtures.event(title: "秘密の面談", day: 2, hour: 10),
                     TestFixtures.event(title: "秘密の読書", day: 2, hour: 19, kind: .margin, marginKind: .reading),
                     TestFixtures.event(title: "誕生日", day: 2, kind: .birthday)]
        for level in FriendShareLevel.allCases {
            let lines = FriendDayContent(date: day, items: items, level: level).lines.joined(separator: "、")
            let text = FriendAvailabilityText.text(from: day, days: 1, items: items, level: level)
            for content in [lines, text] {
                XCTAssertFalse(content.contains("秘密の読書"))
                XCTAssertFalse(content.contains("誕生日"))
                XCTAssertEqual(content.contains("秘密の面談"), level == .titles)
                if level == .hidden { XCTAssertTrue(content.isEmpty) }
                if level == .busyTimes || level == .titles {
                    XCTAssertTrue(content.contains("10:00–12:00"))
                    XCTAssertTrue(content.contains("19:00–21:00 予定あり"))
                }
            }
        }
        XCTAssertTrue(FriendDayContent(date: day, items: [], level: .busyTimes).lines.isEmpty)
        XCTAssertEqual(FriendAvailabilityText.text(from: day, days: 0, items: []), "")
        let work = BaseAvailabilityRule(weekday: Calendar.mira.component(.weekday, from: day), startMinute: 540, endMinute: 1080)
        XCTAssertEqual(FriendDayContent(date: day, items: [], baseRules: [work], level: .busyTimes).lines, ["09:00–18:00 予定あり"])
    }

    func testLevelPersistsThroughStore() async throws {
        let schema = Schema([AppSettingsEntity.self, CalendarItemEntity.self, MarginGoalEntity.self,
            BaseRuleEntity.self, AdjustmentEntity.self, PendingInvitationEntity.self,
            LoadRuleEntity.self, ImportantPersonEntity.self, ConversationCaseEntity.self, RebalanceProposalEntity.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let store = MiraStore(container: container, classifier: RuleBasedSemanticClassifier(), conversationInterpreter: RuleBasedConversationInterpreter(), draftStorage: DraftStorage())
        await store.bootstrap()
        store.addImportantPerson(name: "はる", monthlyTarget: nil)
        let person = try XCTUnwrap(store.importantPeople.first)
        XCTAssertEqual(store.friendShareLevel(for: person), .freeOnly)
        store.setFriendShareLevel(.titles, for: person)
        let fetched = try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<ImportantPersonEntity>()).first)
        XCTAssertEqual(store.friendShareLevel(for: fetched), .titles)
        fetched.friendShareLevelRaw = "unknown"
        XCTAssertEqual(store.friendShareLevel(for: fetched), .freeOnly)
    }

    func testRenderShareCard() throws {
        let card = FriendShareCard(month: TestFixtures.september,
            items: [TestFixtures.event(title: "面談", day: 2, hour: 10), TestFixtures.event(title: "秘密", day: 3, kind: .margin, marginKind: .reading)],
            palette: MiraThemePalette(kind: .softMinimal, colorScheme: .light), weekStartDay: .monday,
            referenceDate: TestFixtures.date(day: 1), level: .busyTimes, recipientName: "はる")
        let renderer = ImageRenderer(content: card)
        let image = try XCTUnwrap(renderer.uiImage)
        let attachment = XCTAttachment(image: image)
        attachment.name = "friend-share-rendered-card"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
