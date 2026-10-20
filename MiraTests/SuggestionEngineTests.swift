import XCTest
@testable import Mira

// Loop goals S1, S2, S6, S7 and U3/U4 (docs/loop-goals.md).
final class SuggestionEngineTests: XCTestCase {
    private let calendar = Calendar.mira
    private let now = DemoClock.standard.now
    private let engine = SuggestionEngine()
    private var nextWeek: WeekKey { WeekKey(containing: now).adding(weeks: 1) }

    // MARK: S1

    func testInterpretsVagueSelfTimeRequest() {
        let interpreter = IntentInterpreter()
        XCTAssertEqual(interpreter.interpret("来週は自分の時間を増やしたい"), .increaseSelfTime(scope: .nextWeek, kind: nil))
        XCTAssertEqual(interpreter.interpret("今週はゆっくり休みたい"), .increaseSelfTime(scope: .thisWeek, kind: .rest))
        XCTAssertEqual(interpreter.interpret("来週は読書したい"), .increaseSelfTime(scope: .nextWeek, kind: .reading))
        XCTAssertEqual(interpreter.interpret("来週は夜を空けたい"), .protectEvenings(scope: .nextWeek))
        XCTAssertEqual(interpreter.interpret("ラーメン"), .unknown)
    }

    func testUnknownRequestStillOffersChoicesThatProduceSuggestions() {
        XCTAssertFalse(IntentInterpreter.fallbackOptions.isEmpty)
        for option in IntentInterpreter.fallbackOptions {
            XCTAssertNotNil(engine.suggestion(for: option, now: now, items: [], baseRules: [], trend: nil), option.label)
        }
    }

    func testRequestSuggestionPreviewsMarginsInRequestedWeek() throws {
        let suggestion = try XCTUnwrap(engine.suggestion(
            for: .increaseSelfTime(scope: .nextWeek, kind: nil),
            now: now, items: [], baseRules: [], trend: nil
        ))
        XCTAssertEqual(suggestion.status, .pending)
        XCTAssertEqual(suggestion.origin, .request)
        XCTAssertGreaterThan(suggestion.addedHours, 0)
        XCTAssertTrue(suggestion.title.contains("+"))
        XCTAssertFalse(suggestion.reason.isEmpty)
        let week = nextWeek.interval()
        XCTAssertTrue(suggestion.margins.allSatisfy { week.contains($0.startDate) && week.contains($0.endDate) })
        XCTAssertEqual(Set(suggestion.margins.map { calendar.startOfDay(for: $0.startDate) }).count, suggestion.margins.count)
    }

    func testThisWeekSuggestionNeverStartsInThePast() throws {
        let suggestion = try XCTUnwrap(engine.suggestion(
            for: .increaseSelfTime(scope: .thisWeek, kind: nil),
            now: now, items: [], baseRules: [], trend: nil
        ))
        XCTAssertTrue(suggestion.margins.allSatisfy { $0.startDate >= now })
    }

    func testSuggestionAvoidsEventsMarginsAndBaseRules() throws {
        let monday = nextWeek.start
        let events = (0..<7).filter { $0 % 2 == 0 }.map { offset in
            eventItem(on: monday.addingDays(offset), hour: 18, hours: 5)
        }
        let rules = [BaseAvailabilityRule(weekday: 7, startMinute: 0, endMinute: 24 * 60)]
        let suggestion = try XCTUnwrap(engine.suggestion(
            for: .increaseSelfTime(scope: .nextWeek, kind: nil),
            now: now, items: events, baseRules: rules, trend: nil
        ))
        for margin in suggestion.margins {
            XCTAssertFalse(events.contains { $0.occupiedInterval.intersects(margin.interval) })
            XCTAssertNotEqual(calendar.component(.weekday, from: margin.startDate), 7)
        }
    }

    func testSuggestionUsesRealGapsWhenUsualEveningsAreTaken() throws {
        // Every evening 18:00–20:00 is booked; 20:00–23:00 is still free.
        let events = nextWeek.days.map { eventItem(on: $0, hour: 18, hours: 2) }
        let weekendDays = Set(nextWeek.days.filter { [1, 7].contains(calendar.component(.weekday, from: $0)) }.map { calendar.startOfDay(for: $0) })
        let weekendBlocks = weekendDays.map { eventItem(on: $0, hour: 9, hours: 9) }
        let suggestion = try XCTUnwrap(engine.suggestion(
            for: .increaseSelfTime(scope: .nextWeek, kind: nil),
            now: now, items: events + weekendBlocks, baseRules: [], trend: nil
        ))
        for margin in suggestion.margins {
            XCTAssertFalse((events + weekendBlocks).contains { $0.occupiedInterval.intersects(margin.interval) && ($0.occupiedInterval.intersection(with: margin.interval)?.duration ?? 0) > 0 })
            XCTAssertGreaterThanOrEqual(margin.hours, SelfTimePlanner.minimumHours)
            XCTAssertGreaterThanOrEqual(calendar.component(.hour, from: margin.startDate), 20)
        }
    }

    func testApplicableMarginsDropOnesThatNowCollide() throws {
        let suggestion = try XCTUnwrap(engine.suggestion(
            for: .increaseSelfTime(scope: .nextWeek, kind: nil),
            now: now, items: [], baseRules: [], trend: nil
        ))
        let first = try XCTUnwrap(suggestion.margins.first)
        let blocker = eventItem(on: first.startDate, hour: calendar.component(.hour, from: first.startDate), hours: 1)
        let applicable = engine.applicableMargins(of: suggestion, items: [blocker])
        XCTAssertFalse(applicable.contains(first))
        XCTAssertEqual(applicable.count, suggestion.margins.count - 1)
        XCTAssertTrue(applicable.allSatisfy { $0.calendarItem().kind == .margin })
    }

    // MARK: S2

    func testProactiveSuggestionWhenNextWeekIsBelowTarget() throws {
        let suggestion = try XCTUnwrap(proactive(items: [], history: []))
        XCTAssertEqual(suggestion.origin, .proactive)
        XCTAssertEqual(suggestion.status, .pending)
        XCTAssertEqual(suggestion.weekStart, nextWeek.start)
        XCTAssertFalse(suggestion.reason.isEmpty)
    }

    func testNoProactiveSuggestionWhenTargetIsMet() {
        let margins = nextWeek.days.map { marginItem(on: $0, hour: 9, hours: 12) }
        XCTAssertNil(proactive(items: margins, history: []))
    }

    func testProactiveSuggestionIsNotRepeatedForTheSameWeek() throws {
        var first = try XCTUnwrap(proactive(items: [], history: []))
        XCTAssertNil(proactive(items: [], history: [first]))
        first.status = .dismissed
        XCTAssertNil(proactive(items: [], history: [first]))
    }

    func testNotificationOnlyForNewProactiveSuggestionsAndOncePerDay() throws {
        let policy = SuggestionNotificationPolicy()
        let proactiveSuggestion = try XCTUnwrap(proactive(items: [], history: []))
        let requested = try XCTUnwrap(engine.suggestion(
            for: .increaseSelfTime(scope: .nextWeek, kind: nil), now: now, items: [], baseRules: [], trend: nil
        ))
        XCTAssertTrue(policy.shouldNotify(proactiveSuggestion, notificationsEnabled: true, lastNotifiedAt: nil, now: now))
        XCTAssertFalse(policy.shouldNotify(proactiveSuggestion, notificationsEnabled: false, lastNotifiedAt: nil, now: now))
        XCTAssertFalse(policy.shouldNotify(requested, notificationsEnabled: true, lastNotifiedAt: nil, now: now))
        XCTAssertFalse(policy.shouldNotify(proactiveSuggestion, notificationsEnabled: true, lastNotifiedAt: now.addingTimeInterval(-3600), now: now))
        XCTAssertTrue(policy.shouldNotify(proactiveSuggestion, notificationsEnabled: true, lastNotifiedAt: now.addingDays(-1), now: now))
    }

    func testNotificationsWaitUntilMorningDuringQuietHours() {
        let policy = SuggestionNotificationPolicy()
        let late = now.setting(hour: 23)
        let delivery = policy.deliveryDate(now: late)
        XCTAssertEqual(calendar.component(.hour, from: delivery), 8)
        XCTAssertTrue(calendar.isDate(delivery, inSameDayAs: late.addingDays(1)))
        XCTAssertLessThan(policy.deliveryDate(now: now).timeIntervalSince(now), 120)
    }

    // MARK: U4

    func testAtMostThreePendingSuggestionsAreVisible() throws {
        let base = try XCTUnwrap(engine.suggestion(
            for: .increaseSelfTime(scope: .nextWeek, kind: nil), now: now, items: [], baseRules: [], trend: nil
        ))
        var suggestions = (0..<5).map { index -> Suggestion in
            var copy = base
            copy.id = UUID()
            copy.createdAt = now.addingTimeInterval(Double(index))
            return copy
        }
        suggestions[0].status = .applied
        let visible = engine.visiblePending(suggestions)
        XCTAssertEqual(visible.count, SuggestionEngine.maxVisiblePending)
        XCTAssertTrue(visible.allSatisfy { $0.status == .pending })
    }

    // MARK: S6

    func testTrendNeedsEnoughSamplesAndCanBeDisabled() {
        let history = appliedHistory(weekday: 6, count: 3)
        XCTAssertNil(TrendAnalyzer().analyze(Array(history.prefix(2)), enabled: true))
        XCTAssertNil(TrendAnalyzer().analyze(history, enabled: false))
        XCTAssertNotNil(TrendAnalyzer().analyze(history, enabled: true))
    }

    func testTrendSteersSuggestionAndIsLabelled() throws {
        let trend = try XCTUnwrap(TrendAnalyzer().analyze(appliedHistory(weekday: 6, count: 3), enabled: true))
        let suggestion = try XCTUnwrap(engine.suggestion(
            for: .increaseSelfTime(scope: .nextWeek, kind: nil), now: now, items: [], baseRules: [], trend: trend
        ))
        XCTAssertTrue(suggestion.usesTrend)
        XCTAssertTrue(suggestion.reason.contains("最近の傾向から"))
        XCTAssertTrue(suggestion.margins.contains { calendar.component(.weekday, from: $0.startDate) == 6 })

        let plain = try XCTUnwrap(engine.suggestion(
            for: .increaseSelfTime(scope: .nextWeek, kind: nil), now: now, items: [], baseRules: [], trend: nil
        ))
        XCTAssertFalse(plain.usesTrend)
        XCTAssertFalse(plain.reason.contains("傾向"))
    }

    func testExplicitBaseRulesBeatTrend() throws {
        let trend = try XCTUnwrap(TrendAnalyzer().analyze(appliedHistory(weekday: 6, count: 3), enabled: true))
        let fridayOff = BaseAvailabilityRule(weekday: 6, startMinute: 0, endMinute: 24 * 60)
        let suggestion = try XCTUnwrap(engine.suggestion(
            for: .increaseSelfTime(scope: .nextWeek, kind: nil), now: now, items: [], baseRules: [fridayOff], trend: trend
        ))
        XCTAssertFalse(suggestion.margins.contains { calendar.component(.weekday, from: $0.startDate) == 6 })
    }

    // MARK: S7

    func testWeeklyReviewMeasuresSelfTimeAgainstTarget() {
        let goals = [TestFixtures.goal(.rest, count: 4)]
        let margin = marginItem(on: nextWeek.start, hour: 19, hours: 3)
        var applied = Suggestion(origin: .request, title: "t", reason: "r", weekStart: nextWeek.start, margins: [], usesTrend: false, createdAt: now)
        applied.status = .applied
        let summary = WeeklyReviewEngine().summary(week: nextWeek, items: [margin], goals: goals, suggestions: [applied], satisfaction: .good)
        XCTAssertEqual(summary.selfTimeHours, 3, accuracy: 0.01)
        XCTAssertGreaterThan(summary.targetHours, summary.selfTimeHours)
        XCTAssertEqual(summary.appliedSuggestions, 1)
        XCTAssertEqual(summary.satisfaction, .good)
        XCTAssertLessThan(summary.ratio, 1)
    }

    func testWeeklyTargetSpanningTwoMonthsUsesEachDaysMonth() {
        // The demo week starts on Monday 8/31; only September has goals (rest 4 × 12h = 48h → 1.6h/day).
        let week = WeekKey(containing: now)
        XCTAssertEqual(calendar.component(.month, from: week.start), 8)
        let target = SelfTimePlanner().weeklyTargetHours(for: week, goals: [TestFixtures.goal(.rest, count: 4), TestFixtures.goal(.solo, count: 8)])
        // 6 September days × (48h + 48h) / 30 days = 19.2h
        XCTAssertEqual(target, 19, accuracy: 0.01)
    }

    func testLowSatisfactionMakesNextProposalMoreGenerous() throws {
        let normal = try XCTUnwrap(proactive(items: [], history: [], satisfaction: nil))
        let tired = try XCTUnwrap(proactive(items: [], history: [], satisfaction: .low))
        XCTAssertGreaterThanOrEqual(tired.addedHours, normal.addedHours)
        XCTAssertTrue(tired.reason.contains("しんどかった"))
    }

    // MARK: Helpers

    private func proactive(items: [CalendarItemSnapshot], history: [Suggestion], satisfaction: Satisfaction? = nil) -> Suggestion? {
        engine.proactiveSuggestion(
            now: now,
            items: items,
            goals: [TestFixtures.goal(.rest, count: 4), TestFixtures.goal(.solo, count: 4)],
            baseRules: [],
            history: history,
            lastWeekSatisfaction: satisfaction,
            trend: nil
        )
    }

    private func appliedHistory(weekday: Int, count: Int) -> [Suggestion] {
        let week = WeekKey(containing: now).adding(weeks: -2)
        let day = week.days.first { calendar.component(.weekday, from: $0) == weekday } ?? week.start
        return (0..<count).map { index in
            let start = day.addingDays(-7 * index).setting(hour: 19)
            var suggestion = Suggestion(
                origin: .request,
                title: "t",
                reason: "r",
                weekStart: WeekKey(containing: start).start,
                margins: [SuggestedMargin(kind: .solo, startDate: start, endDate: start.addingTimeInterval(3 * 3600))],
                usesTrend: false,
                createdAt: start
            )
            suggestion.status = .applied
            return suggestion
        }
    }

    private func eventItem(on day: Date, hour: Int, hours: Int) -> CalendarItemSnapshot {
        let start = day.setting(hour: hour)
        return CalendarItemSnapshot(
            id: UUID(), title: "友達とご飯", startDate: start, endDate: start.addingTimeInterval(Double(hours) * 3600),
            isAllDay: false, kind: .confirmed, marginKind: nil, loadClass: .normal, loadReason: "test",
            bufferBeforeMinutes: 0, bufferAfterMinutes: 0, isImportantTime: false, sourceID: nil
        )
    }

    private func marginItem(on day: Date, hour: Int, hours: Int) -> CalendarItemSnapshot {
        var item = eventItem(on: day, hour: hour, hours: hours)
        item.kind = .margin
        item.marginKind = .rest
        item.title = MarginKind.rest.title
        return item
    }
}
