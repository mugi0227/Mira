import SwiftData
import SwiftUI
import XCTest
@testable import Mira

@MainActor
final class FriendShareLevelTests: XCTestCase {
    func testUndeterminedTimesNeverExposeRepresentativeTimes() {
        let day = TestFixtures.date(day: 2)
        var event = TestFixtures.event(title: "面談", day: 2, hour: 10)
        event.exactTimeKnown = false
        var margin = TestFixtures.event(title: "秘密の読書", day: 2, hour: 19, kind: .margin, marginKind: .reading)
        margin.exactTimeKnown = false
        for level in [FriendShareLevel.busyTimes, .titles] {
            let expected = level == .busyTimes ? ["時間未定 予定あり"] : ["時間未定 面談", "時間未定 予定あり"]
            let content = FriendDayContent(date: day, items: [event, margin], level: level)
            XCTAssertEqual(content.lines, expected)
            XCTAssertEqual(content.gridLines, expected)
            let text = FriendAvailabilityText.text(from: day, days: 1, items: [event, margin], level: level)
            for line in expected { XCTAssertTrue(text.contains(line)) }
            XCTAssertFalse(text.contains("10:00"))
            XCTAssertFalse(text.contains("19:00"))
            XCTAssertFalse(text.contains("秘密の読書"))
            let mixed = FriendDayContent(date: day, items: [event, TestFixtures.event(title: "会議", day: 2, hour: 14)], level: level)
            XCTAssertTrue(mixed.lines.contains("14:00–16:00 \(level == .titles ? "会議" : "予定あり")"))
            XCTAssertTrue(mixed.lines.contains(expected[0]))
        }
    }

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

    func testBuffersAreBusyWithoutExposingTheirKinds() {
        let day = TestFixtures.date(day: 2)
        var event = TestFixtures.event(title: "面談", day: 2, hour: 10)
        event.bufferBeforeMinutes = 30
        event.bufferAfterMinutes = 60
        var margin = TestFixtures.event(title: "秘密の読書", day: 2, hour: 13, duration: 1, kind: .margin, marginKind: .reading)
        margin.bufferAfterMinutes = 30
        let items = [event, margin]
        let busy = FriendDayContent(date: day, items: items, level: .busyTimes)
        XCTAssertEqual(busy.lines, ["09:30–14:30 予定あり"])
        XCTAssertEqual(busy.gridLines, ["9:30–14:30"])
        let titles = FriendDayContent(date: day, items: items, level: .titles)
        XCTAssertEqual(titles.lines, ["09:30–10:00 予定あり", "10:00–12:00 面談", "12:00–13:00 予定あり", "13:00–14:00 予定あり", "14:00–14:30 予定あり"])
        XCTAssertEqual(titles.gridLines, ["9:30–10", "10 面談", "12–13", "13–14", "14–14:30"])
        for level in [FriendShareLevel.busyTimes, .titles] {
            let text = FriendAvailabilityText.text(from: day, days: 1, items: items, level: level)
            XCTAssertTrue(text.contains("09:30"))
            XCTAssertTrue(text.contains("14:30"))
            for secret in ["秘密の読書", "支度", "移動", "回復"] { XCTAssertFalse(text.contains(secret)) }
        }
        event.exactTimeKnown = false
        XCTAssertEqual(FriendDayContent(date: day, items: [event], level: .busyTimes).lines, ["時間未定 予定あり"])
    }

    func testBuffersCrossingMidnightAreClippedOnBothDays() {
        var event = TestFixtures.event(title: "深夜の面談", day: 2, hour: 23, duration: 1)
        event.bufferBeforeMinutes = 30
        event.bufferAfterMinutes = 60
        var next = TestFixtures.event(title: "翌日の面談", day: 4, hour: 0, duration: 1)
        next.bufferBeforeMinutes = 30
        for level in [FriendShareLevel.busyTimes, .titles] {
            let middle = FriendDayContent(date: TestFixtures.date(day: 3), items: [event, next], level: level)
            XCTAssertEqual(middle.lines, ["00:00–01:00 予定あり", "23:30–24:00 予定あり"])
            XCTAssertEqual(middle.gridLines, ["0–1", "23:30–24"])
            XCTAssertTrue(FriendDayContent(date: TestFixtures.date(day: 5), items: [event, next], level: level).lines.isEmpty)
        }
        XCTAssertEqual(FriendDayContent(date: TestFixtures.date(day: 2), items: [event], level: .busyTimes).gridLines, ["22:30–24"])
    }

    func testShareGridDayFilterKeepsBuffersAcrossMonthBoundaries() throws {
        let day = TestFixtures.date(day: 1)
        var previous = TestFixtures.event(title: "前月の面談", day: 1, hour: 23, duration: 1)
        previous.startDate = TestFixtures.date(2026, 8, 31, 23)
        previous.endDate = Calendar.mira.startOfDay(for: day)
        previous.bufferAfterMinutes = 60
        let palette = MiraThemePalette(kind: .softMinimal, colorScheme: .light)
        for level in [FriendShareLevel.busyTimes, .titles] {
            let grid = MonthCalendarGrid(month: day, selectedDate: .constant(day), items: [previous], palette: palette, privacyMode: true, friendLevel: level)
            let filtered = grid.itemsForDay(day)
            XCTAssertEqual(filtered.map(\.id), [previous.id])
            let content = FriendDayContent(date: day, items: filtered, level: level)
            XCTAssertEqual(content.lines, ["00:00–01:00 予定あり"])
            XCTAssertEqual(content.gridLines, ["0–1"])
            XCTAssertTrue(grid.itemsForDay(TestFixtures.date(day: 2)).isEmpty)
            let text = FriendAvailabilityText.text(from: day, days: 1, items: [previous], level: level)
            XCTAssertTrue(text.contains("00:00–01:00 予定あり"))
            let card = FriendShareCard(month: day, items: [previous], palette: palette, weekStartDay: .monday, referenceDate: day, level: level)
            let renderer = ImageRenderer(content: card)
            let attachment = XCTAttachment(image: try XCTUnwrap(renderer.uiImage))
            attachment.name = "friend-share-fixture-month-boundary-\(level.rawValue)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        let normal = MonthCalendarGrid(month: day, selectedDate: .constant(day), items: [previous], palette: palette)
        XCTAssertTrue(normal.itemsForDay(day).isEmpty)
    }

    func testRenderShareCard() throws {
        let items = [
            TestFixtures.event(title: "面談", day: 2, hour: 10),
            TestFixtures.event(title: "企画会議", day: 2, hour: 13, duration: 1),
            TestFixtures.event(title: "カフェ", day: 2, hour: 18, duration: 1),
            TestFixtures.event(title: "夕食", day: 2, hour: 20, duration: 1),
            TestFixtures.event(title: "秘密の読書会", day: 3, hour: 19, kind: .margin, marginKind: .reading),
            TestFixtures.event(title: "歯科", day: 4, hour: 10, duration: 1),
            TestFixtures.event(title: "友人とランチ", day: 5, hour: 12)
        ]
        let work = BaseAvailabilityRule(weekday: Calendar.mira.component(.weekday, from: TestFixtures.date(day: 2)), startMinute: 540, endMinute: 1080)
        for level in [FriendShareLevel.busyTimes, .titles] {
            let card = FriendShareCard(month: TestFixtures.september,
                items: items,
                palette: MiraThemePalette(kind: .softMinimal, colorScheme: .light), weekStartDay: .monday,
                referenceDate: TestFixtures.date(day: 1), baseRules: [work], level: level, recipientName: "はる")
            let renderer = ImageRenderer(content: card)
            let image = try XCTUnwrap(renderer.uiImage)
            let attachment = XCTAttachment(image: image)
            attachment.name = "friend-share-fixture-render-\(level.rawValue)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testBusyRangesMergeAcrossEventsMarginsAndWork() {
        let day = TestFixtures.date(day: 2)
        let items = [TestFixtures.event(title: "面談", day: 2, hour: 10),
                     TestFixtures.event(title: "秘密", day: 2, hour: 12, duration: 2, kind: .margin, marginKind: .reading),
                     TestFixtures.event(title: "夕食", day: 2, hour: 19, duration: 1)]
        let work = BaseAvailabilityRule(weekday: Calendar.mira.component(.weekday, from: day), startMinute: 540, endMinute: 660)
        let content = FriendDayContent(date: day, items: items, baseRules: [work], level: .busyTimes)
        XCTAssertEqual(content.lines, ["09:00–14:00 予定あり", "19:00–20:00 予定あり"])
        XCTAssertEqual(content.gridLines, ["9–14", "19–20"])
        let text = FriendAvailabilityText.text(from: day, items: items, level: .busyTimes)
        XCTAssertTrue(text.hasPrefix("この2週間の予定です（埋まりだけ）。"))
    }

    func testAllDaySuppressesOtherBusyRangesAndCoveredWork() {
        let day = TestFixtures.date(day: 2)
        var allDay = TestFixtures.event(title: "出張", day: 2)
        allDay.isAllDay = true
        allDay.occupiesTime = true
        let work = BaseAvailabilityRule(weekday: Calendar.mira.component(.weekday, from: day), startMinute: 540, endMinute: 1080)
        let items = [allDay, TestFixtures.event(title: "面談", day: 2, hour: 10)]
        let busy = FriendDayContent(date: day, items: items, baseRules: [work], level: .busyTimes)
        XCTAssertEqual(busy.lines, ["終日 予定あり"])
        XCTAssertEqual(busy.gridLines, ["終日"])
        let titles = FriendDayContent(date: day, items: items, baseRules: [work], level: .titles)
        XCTAssertEqual(titles.gridLines, ["終日 出張", "10 面談"])
        XCTAssertEqual(titles.lines.count, 2)
    }

    func testCompactFormattingAndCoveredBaseRule() {
        let day = TestFixtures.date(day: 2)
        var event = TestFixtures.event(title: "面談", day: 2, hour: 10, duration: 2)
        event.startDate = event.startDate.addingTimeInterval(1800)
        let margin = TestFixtures.event(title: "秘密", day: 2, hour: 19, kind: .margin, marginKind: .reading)
        let work = BaseAvailabilityRule(weekday: Calendar.mira.component(.weekday, from: day), startMinute: 630, endMinute: 720)
        let content = FriendDayContent(date: day, items: [event, margin], baseRules: [work], level: .titles)
        XCTAssertEqual(content.gridLines, ["10:30 面談", "19–21"])
        XCTAssertEqual(content.lines, ["10:30–12:00 面談", "19:00–21:00 予定あり"])
        XCTAssertEqual(FriendDayContent(date: day, items: [event], level: .busyTimes).gridLines, ["10:30–12"])
        XCTAssertTrue(FriendDayContent(date: day, items: [event], level: .hidden).gridLines.isEmpty)
        XCTAssertTrue(FriendAvailabilityText.text(from: day, items: [event], level: .titles).contains("余白は「予定あり」"))
    }
}
