import XCTest

final class HomeWhitespaceUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testSoftMinimalRingSurroundsDateWithoutSeparateMeterRow() {
        launchHome(theme: "softMinimal")
        let ring = element("whitespace-2026-09-01")
        let date = app.buttons["calendar-date-2026-09-01"]
        XCTAssertTrue(ring.waitForExistence(timeout: 5))
        XCTAssertTrue(ring.label.contains("余白"))
        XCTAssertTrue(ring.label.contains("7時間"))
        XCTAssertTrue(ring.label.contains("パーセント"))
        XCTAssertEqual(ring.frame.midX, date.frame.midX, accuracy: 1)
        XCTAssertEqual(ring.frame.midY, date.frame.midY, accuracy: 1)
        XCTAssertGreaterThan(ring.frame.height, 26)
        capture("soft-minimal-date-ring")
    }

    func testDailyMetersNavigateWithMonthAndKeepDayNavigation() {
        launchHome(theme: "silhouetteCat")
        let first = element("whitespace-2026-09-01")
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertTrue(first.label.contains("7時間"))
        XCTAssertTrue(element("whitespace-2026-09-06").label.contains("16時間"))
        app.buttons["次の月"].tap()
        XCTAssertTrue(element("whitespace-2026-10-01").waitForExistence(timeout: 5))
        app.buttons["前の月"].tap()
        let day = element("calendar-day-2026-09-06")
        XCTAssertTrue(day.waitForExistence(timeout: 5))
        app.buttons["calendar-date-2026-09-06"].tap()
        Thread.sleep(forTimeInterval: 1)
        app.buttons["inlineDayTimeBar"].tap()
        XCTAssertTrue(app.navigationBars.matching(NSPredicate(format: "identifier CONTAINS %@", "9月6日")).firstMatch.waitForExistence(timeout: 5))
        capture("whitespace-day-navigation")
    }

    func testTodayAndOpenedDayHaveIndependentHighlights() {
        launchHome(theme: "softMinimal")
        let today = app.buttons["calendar-date-2026-09-01"]
        let otherDay = app.buttons["calendar-date-2026-09-02"]
        let panel = element("inlineDayPanel")

        XCTAssertTrue(today.label.contains("今日"))
        XCTAssertFalse(today.isSelected)

        otherDay.tap()
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertTrue(otherDay.isSelected)
        XCTAssertFalse(otherDay.label.contains("今日"))
        XCTAssertFalse(today.isSelected)
        XCTAssertTrue(today.label.contains("今日"))
        capture("soft-minimal-today-and-opened-day")

        today.tap()
        XCTAssertTrue(today.isSelected)
        XCTAssertTrue(today.label.contains("今日"))
        XCTAssertFalse(otherDay.isSelected)

        today.tap()
        XCTAssertTrue(panel.waitForNonExistence(timeout: 5))
        XCTAssertFalse(today.isSelected)
        XCTAssertTrue(today.label.contains("今日"))
    }

    func testAllDayEventStaysAboveTheScrollingTimeline() {
        launchHome(theme: "softMinimal")
        app.buttons["calendar-date-2026-09-07"].tap()
        let work = element("inlineDayWork-0")
        XCTAssertTrue(work.waitForExistence(timeout: 5))
        let inlineEvent = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "inlineDayEvent-")).firstMatch
        XCTAssertTrue(inlineEvent.exists)
        XCTAssertLessThan(work.frame.maxY, inlineEvent.frame.minY)
        Thread.sleep(forTimeInterval: 1)
        app.buttons["inlineDayTimeBar"].tap()
        let allDayEvent = app.buttons["美容院、終日"]
        XCTAssertTrue(allDayEvent.waitForExistence(timeout: 5))
        XCTAssertTrue(allDayEvent.isHittable)

        let timeline = app.scrollViews.firstMatch
        let lastHour = app.staticTexts["23:00"]
        let initialEventY = allDayEvent.frame.minY
        let initialLastHourY = lastHour.frame.minY
        XCTAssertGreaterThan(initialLastHourY, timeline.frame.maxY)
        capture("all-day-timeline-initial")

        for _ in 0..<4 { timeline.swipeUp(velocity: .fast) }
        XCTAssertTrue(lastHour.isHittable)
        XCTAssertLessThan(lastHour.frame.minY, initialLastHourY)
        XCTAssertTrue(allDayEvent.isHittable)
        XCTAssertEqual(allDayEvent.frame.minY, initialEventY, accuracy: 1)
        XCTAssertLessThan(allDayEvent.frame.maxY, lastHour.frame.minY)
        capture("all-day-timeline-scrolled")

        allDayEvent.tap()
        XCTAssertTrue(app.navigationBars["詳細"].waitForExistence(timeout: 5))
    }

    func testNonOccupyingEventUpdatesRingAndPersistsAcrossLaunch() {
        launchHome(theme: "onelineCat")
        let ring = element("whitespace-2026-09-05")
        XCTAssertTrue(ring.waitForExistence(timeout: 5))
        XCTAssertTrue(ring.label.contains("12時間"))
        let dinner = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "みんなでご飯、")).firstMatch
        XCTAssertTrue(dinner.waitForExistence(timeout: 5))
        dinner.tap()
        let toggle = app.buttons["eventOccupiesTime"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()
        app.buttons["閉じる"].tap()
        XCTAssertTrue(ring.label.contains("16時間"))
        app.terminate()
        app.launchArguments.removeAll { $0 == "-reset-demo" }
        app.launch()
        XCTAssertTrue(element("whitespace-2026-09-05").waitForExistence(timeout: 10))
        XCTAssertTrue(element("whitespace-2026-09-05").label.contains("16時間"))
        capture("whitespace-memo-persisted")
    }

    func testSummaryExplainsMeaningAndFriendViewHidesPersonalMeters() {
        launchHome(theme: "pixelCat")
        let summary = app.buttons["monthWhitespaceSummary"]
        for _ in 0..<3 where !summary.isHittable { app.swipeUp() }
        XCTAssertTrue(summary.isHittable)
        summary.tap()
        XCTAssertTrue(app.navigationBars["余白メーターについて"].waitForExistence(timeout: 5))
        capture("whitespace-explanation")
        app.buttons["閉じる"].tap()
        app.swipeDown()
        app.swipeDown()
        app.buttons["friendViewToggle"].tap()
        XCTAssertFalse(element("whitespace-2026-09-01").exists)
        XCTAssertFalse(app.buttons["monthWhitespaceSummary"].exists)
        XCTAssertFalse(element("workDayMark-2026-09-01").exists)
        XCTAssertFalse(app.buttons["calendar-date-2026-09-01"].label.contains("仕事の日"))
        capture("whitespace-friend-privacy")
    }

    func testInlinePanelPlacementToggleEmptyAndEventDetail() {
        launchHome(theme: "softMinimal")
        let day = app.buttons["calendar-date-2026-09-02"]
        day.tap()
        let panel = element("inlineDayPanel")
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(panel.frame.minY, day.frame.maxY)
        XCTAssertLessThan(panel.frame.maxY, app.buttons["calendar-date-2026-09-07"].frame.minY)
        capture("panel-busy")
        let event = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "inlineDayEvent-")).firstMatch
        XCTAssertTrue(event.exists)
        event.tap()
        XCTAssertTrue(app.navigationBars["詳細"].waitForExistence(timeout: 5))
        app.buttons["閉じる"].tap()
        day.tap()
        XCTAssertTrue(panel.waitForNonExistence(timeout: 5))
        app.buttons["calendar-date-2026-09-03"].tap()
        app.buttons["workDayToggle"].tap()
        XCTAssertTrue(element("inlineDayEmpty").waitForExistence(timeout: 5))
        XCTAssertFalse(element("inlineDayWork-0").exists)
        capture("panel-empty")
        app.buttons["inlineDayTimeBar"].tap()
        XCTAssertTrue(app.buttons["この日に予定を追加"].waitForExistence(timeout: 5))
    }

    func testInlinePanelLastWeekScreenshot() {
        launchHome(theme: "softMinimal")
        let day = app.buttons["calendar-date-2026-09-30"]
        for _ in 0..<4 where !day.isHittable { app.swipeUp() }
        day.tap()
        let panel = element("inlineDayPanel")
        let scroll = app.scrollViews["homeScroll"]
        for _ in 0..<6 where panel.frame.maxY > scroll.frame.maxY - 20 {
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.7))
                .press(forDuration: 0.01, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5)))
        }
        XCTAssertTrue(panel.exists)
        let work = element("inlineDayWork-0")
        XCTAssertTrue(work.exists)
        XCTAssertEqual(work.label, "仕事  9:00–18:00")
        let event = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "inlineDayEvent-")).firstMatch
        XCTAssertTrue(event.exists)
        XCTAssertLessThan(work.frame.maxY, event.frame.minY)
        XCTAssertFalse(element("inlineDayEmpty").exists)
        capture("panel-last-week")
        for _ in 0..<4 { scroll.swipeUp(velocity: .fast) }
        XCTAssertLessThan(panel.frame.maxY, app.tabBars.firstMatch.frame.minY - 16)
        capture("panel-last-week-max-scroll")
    }

    func testInlinePanelOpensNeighborMonthDay() {
        launchHome(theme: "softMinimal")
        app.buttons["calendar-date-2026-08-31"].tap()
        XCTAssertTrue(element("inlineDayPanel").waitForExistence(timeout: 5))
        XCTAssertTrue(element("homeMonthHeading").label.hasPrefix("2026年8月"))
        let scroll = app.scrollViews["homeScroll"]
        for _ in 0..<6 where !app.buttons["inlineDayTimeBar"].isHittable {
            scroll.swipeUp()
        }
        XCTAssertTrue(app.buttons["inlineDayTimeBar"].isHittable)
        XCTAssertGreaterThan(element("inlineDayPanel").frame.height, 100)
        capture("panel-neighbor-new-week")
    }

    func testInlinePanelMotionOpenMoveAndClose() {
        launchHome(theme: "softMinimal")
        let panel = element("inlineDayPanel")
        app.buttons["calendar-date-2026-09-03"].tap()
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        app.buttons["calendar-date-2026-09-09"].tap()
        XCTAssertTrue(panel.exists)
        let belowWeek = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            panel.exists && panel.frame.minY > self.app.buttons["calendar-date-2026-09-09"].frame.maxY
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [belowWeek], timeout: 5), .completed)
        app.buttons["calendar-date-2026-09-09"].tap()
        XCTAssertTrue(panel.waitForNonExistence(timeout: 5))
    }

    func testInlinePanelWorkDayToggleUpdatesMonthAndExplains() {
        launchHome(theme: "softMinimal")
        app.buttons["calendar-date-2026-09-03"].tap()
        let toggle = app.buttons["workDayToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        let mark = element("workDayMark-2026-09-03")
        XCTAssertTrue(mark.exists)
        XCTAssertEqual(toggle.value as? String, "オン")
        XCTAssertEqual(app.buttons["inlineDayTimeBar"].value as? String, "仕事 9:00–18:00")
        XCTAssertEqual(element("inlineDayWork-0").label, "仕事  9:00–18:00")
        XCTAssertFalse(element("inlineDayEmpty").exists)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "inlineDayEvent-")).count, 0)
        capture("panel-work-no-events")
        toggle.tap()
        XCTAssertTrue(mark.waitForNonExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "オフ")
        XCTAssertFalse((app.buttons["inlineDayTimeBar"].value as? String ?? "").contains("仕事"))
        XCTAssertFalse(element("inlineDayWork-0").exists)
        XCTAssertTrue(element("inlineDayEmpty").exists)
        capture("panel-nonwork-no-events")
        toggle.tap()
        XCTAssertTrue(mark.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["inlineDayTimeBar"].value as? String, "仕事 9:00–18:00")
        capture("panel-work-day")
        app.buttons["workDayInfoButton"].tap()
        XCTAssertTrue(element("workDayExplanation").waitForExistence(timeout: 5))
        capture("panel-work-day-explanation")
    }

    func testInlinePanelSeveralEventsScreenshotAndAdd() {
        launchHome(theme: "softMinimal")
        app.buttons["calendar-date-2026-09-02"].tap()
        Thread.sleep(forTimeInterval: 1)
        for title in ["打ち合わせ", "カフェでひと息"] {
            app.buttons["inlineDayAdd"].tap()
            let field = app.textFields["例：友達とご飯"]
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            field.tap()
            field.typeText(title)
            app.navigationBars["予定を追加"].buttons["追加"].tap()
            let approve = app.buttons["このまま追加する"]
            if approve.waitForExistence(timeout: 3) { approve.tap() }
            XCTAssertTrue(app.buttons["inlineDayAdd"].waitForExistence(timeout: 5))
        }
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "inlineDayEvent-")).count, 3)
        let dismissUndo = app.buttons["取り消しの案内を閉じる"]
        if dismissUndo.exists { dismissUndo.tap() }
        XCTAssertTrue(app.staticTexts["appToast"].waitForNonExistence(timeout: 6))
        let panel = element("inlineDayPanel")
        let scroll = app.scrollViews["homeScroll"]
        for _ in 0..<4 where panel.frame.maxY > app.tabBars.firstMatch.frame.minY - 16 {
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.7))
                .press(forDuration: 0.01, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.55)))
        }
        capture("panel-several-events")
    }

    private func launchHome(theme: String) {
        app.launchArguments = ["-ui-testing", "-reset-demo", "-ui-theme", theme,
                               "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        let recommended = app.buttons["おすすめを確認"]
        if recommended.waitForExistence(timeout: 5) {
            recommended.tap()
            let start = app.buttons["余白を置いて始める"]
            XCTAssertTrue(start.waitForExistence(timeout: 5))
            start.tap()
        }
        XCTAssertTrue(element("monthCalendar").waitForExistence(timeout: 12))
        // The onboarding success toast otherwise temporarily covers the header.
        Thread.sleep(forTimeInterval: 3)
    }

    func testSoftMinimalHomeReachesBottomCard() {
        launchHome(theme: "softMinimal")
        capture("home-initial")
        let scroll = app.scrollViews["homeScroll"]
        XCTAssertGreaterThanOrEqual(scroll.frame.maxY, app.frame.maxY - 1)
        for _ in 0..<6 { scroll.swipeUp(velocity: .fast) }
        capture("home-bottom")
        let goals = element("homeGoalSummary")
        XCTAssertTrue(goals.isHittable)
        XCTAssertGreaterThanOrEqual(goals.frame.minY, scroll.frame.minY)
        XCTAssertLessThanOrEqual(goals.frame.maxY, app.tabBars.firstMatch.frame.minY)
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
