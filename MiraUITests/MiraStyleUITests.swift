import XCTest

final class MiraStyleUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-demo", "-ui-theme", "pixelCat", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
    }

    func testCalendarLeavesRoomAroundRoundedCorners() {
        launchHome()
        let calendar = app.descendants(matching: .any)["monthCalendar"].firstMatch
        XCTAssertTrue(calendar.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(calendar.frame.minX - app.frame.minX, 20)
        XCTAssertGreaterThanOrEqual(app.frame.maxX - calendar.frame.maxX, 20)

        // Both edge columns must remain inside the card, not under its curve.
        let monday = app.descendants(matching: .any)["calendar-day-2026-08-31"].firstMatch
        let sunday = app.descendants(matching: .any)["calendar-day-2026-09-06"].firstMatch
        XCTAssertTrue(monday.exists)
        XCTAssertTrue(sunday.exists)
        XCTAssertGreaterThanOrEqual(monday.frame.minX - calendar.frame.minX, 24)
        XCTAssertGreaterThanOrEqual(calendar.frame.maxX - sunday.frame.maxX, 24)
        XCTAssertGreaterThanOrEqual(monday.frame.minY - calendar.frame.minY, 44)
        let scroll = app.scrollViews["homeScroll"]
        XCTAssertTrue(scroll.exists)
        let companion = app.buttons["miraCompanionButton"]
        XCTAssertGreaterThanOrEqual(companion.frame.minY, scroll.frame.maxY)
        // In the demo's five-week month both lower corners must rest above the
        // fading footer, not behind its avatar or a clipped horizontal band.
        XCTAssertGreaterThanOrEqual(scroll.frame.maxY - calendar.frame.maxY, 8)
        XCTAssertGreaterThanOrEqual(companion.frame.minY - calendar.frame.maxY, 8)
        capture("roomier-calendar")
    }

    func testNextStepCardKeepsTextAwayFromCornersAndOpensEvent() {
        launchHome()
        let card = app.descendants(matching: .any)["homeNextStepCard"].firstMatch
        for _ in 0..<4 where !card.isHittable || card.frame.maxY > app.buttons["miraTab-home"].frame.minY {
            app.swipeUp()
        }
        XCTAssertTrue(card.exists)
        let label = card.staticTexts["次の予定"].firstMatch
        XCTAssertTrue(label.exists)
        XCTAssertGreaterThanOrEqual(label.frame.minX - card.frame.minX, 20)
        XCTAssertGreaterThanOrEqual(label.frame.minY - card.frame.minY, 20)
        let event = card.buttons.firstMatch
        XCTAssertTrue(event.isHittable)
        XCTAssertGreaterThanOrEqual(card.frame.maxX - event.frame.maxX, 20)
        XCTAssertGreaterThanOrEqual(card.frame.maxY - event.frame.maxY, 20)
        capture("roomier-next-step")
        event.tap()
        XCTAssertTrue(app.buttons["閉じる"].waitForExistence(timeout: 5))
    }

    func testGoalPillsStayInsideScreenGutters() {
        launchHome()
        let scroll = app.scrollViews["homeScroll"]
        scroll.swipeUp()
        scroll.swipeUp()
        let summary = app.descendants(matching: .any)["homeGoalSummary"].firstMatch
        for _ in 0..<4 where !summary.isHittable { app.swipeUp() }
        let pills = summary.descendants(matching: .any).matching(identifier: "homeGoalPill")
        XCTAssertEqual(pills.count, 3)
        for index in 0..<pills.count {
            let pill = pills.element(boundBy: index)
            XCTAssertGreaterThanOrEqual(pill.frame.minX - app.frame.minX, 20)
            XCTAssertGreaterThanOrEqual(app.frame.maxX - pill.frame.maxX, 20)
            XCTAssertLessThanOrEqual(pill.frame.maxY + 20, scroll.frame.maxY)
        }
        let card = app.descendants(matching: .any)["homeNextStepCard"].firstMatch
        XCTAssertLessThanOrEqual(card.frame.maxY + 20, scroll.frame.maxY)
        XCTAssertLessThanOrEqual(card.frame.maxY + 20, app.buttons["miraCompanionButton"].frame.minY)
        XCTAssertTrue(card.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "次の余白")).firstMatch.isHittable)
        capture("roomier-goals")
    }

    func testRoundedTabsKeepSelectionAndNavigation() {
        launchHome()
        for tab in ["adjustments", "margins", "settings", "home"] {
            let button = app.buttons["miraTab-\(tab)"]
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            button.tap()
            XCTAssertEqual(button.value as? String, "選択中")
        }
        XCTAssertTrue(app.buttons["miraCompanionButton"].isHittable)
        capture("rounded-home")
    }

    func testMonthControlsStillOpenADay() {
        launchHome()
        let september = app.staticTexts["2026年9月"]
        XCTAssertTrue(september.waitForExistence(timeout: 5))
        app.buttons["次の月"].tap()
        XCTAssertTrue(app.staticTexts["2026年10月"].waitForExistence(timeout: 5))
        app.buttons["前の月"].tap()
        XCTAssertTrue(september.waitForExistence(timeout: 5))
        let day = app.descendants(matching: .any)["calendar-day-2026-09-02"].firstMatch
        XCTAssertTrue(day.exists)
        // The container's accessibility frame includes its event chips. Tap
        // the actual date label rather than guessing its offset in that frame.
        let dayHeader = day.staticTexts["2"].firstMatch
        XCTAssertTrue(dayHeader.isHittable)
        dayHeader.tap()
        XCTAssertTrue(app.buttons["この日に予定を追加"].waitForExistence(timeout: 5))
        capture("rounded-day")
    }

    func testHomeScrollViewportStaysBelowStatusBar() {
        launchHome()
        let scroll = app.scrollViews["homeScroll"]
        let statusBar = app.statusBars.firstMatch
        XCTAssertTrue(scroll.exists)
        XCTAssertTrue(statusBar.exists)
        let viewport = scroll.frame
        XCTAssertGreaterThanOrEqual(viewport.minY, statusBar.frame.maxY)
        let firstDay = app.buttons["calendar-day-2026-08-31"].firstMatch
        let initialDayY = firstDay.frame.minY

        scroll.swipeUp()

        XCTAssertEqual(scroll.frame.minY, viewport.minY, accuracy: 1)
        XCTAssertGreaterThanOrEqual(scroll.frame.minY, statusBar.frame.maxY)
        XCTAssertLessThan(firstDay.frame.minY, initialDayY)
        XCTAssertLessThan(firstDay.frame.maxY, scroll.frame.minY)
        XCTAssertTrue(app.buttons["miraCompanionButton"].isHittable)
        // Raw offscreen accessibility frames can cross the safe area; this
        // screenshot also records the rendered clipping boundary for review.
        capture("calendar-scrolled-safe-area")
    }

    func testCompactCalendarOverflowOpensAllEventsForTheDay() {
        launchHome()
        let day = app.descendants(matching: .any)["calendar-day-2026-09-02"].firstMatch
        day.staticTexts["2"].firstMatch.tap()
        let add = app.buttons["この日に予定を追加"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let title = app.textFields["例：友達とご飯"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Dinner")
        app.navigationBars["予定を追加"].buttons["追加"].tap()
        let approve = app.buttons["このまま追加する"]
        XCTAssertTrue(approve.waitForExistence(timeout: 5))
        approve.tap()
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        let dinner = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Dinner、")).firstMatch
        XCTAssertTrue(dinner.waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()

        let overflow = app.buttons["calendar-overflow-2026-09-02"]
        XCTAssertTrue(overflow.waitForExistence(timeout: 5))
        XCTAssertTrue(overflow.isHittable)
        overflow.tap()
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "仕事、")).firstMatch.exists)
        XCTAssertTrue(dinner.exists)
        capture("compact-calendar-day-events")
    }

    func testToastLeavesMonthControlsReachable() {
        app.launchArguments += ["-ui-testing-persistent-toast"]
        launchHome()
        let toast = app.staticTexts["appToast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 5))
        let toastFrame = toast.frame
        let month = app.staticTexts["2026年9月"]
        XCTAssertGreaterThanOrEqual(month.frame.minY, toastFrame.maxY)
        for label in ["前の月", "次の月", "追加メニュー"] {
            let button = app.buttons[label]
            XCTAssertTrue(button.isHittable)
            XCTAssertFalse(button.frame.intersects(toastFrame))
        }
        capture("toast-clear-header")
        app.buttons["次の月"].tap()
        XCTAssertTrue(app.staticTexts["2026年10月"].waitForExistence(timeout: 5))
        XCTAssertTrue(toast.exists)
    }

    func testChatUsesNaturalVoiceAndAccessibleControls() {
        launchHome()
        app.buttons["miraCompanionButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["miraChatInput"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "にゃ")).count, 0)
        let suggestions = app.buttons.matching(identifier: "chatSuggestion")
        XCTAssertGreaterThan(suggestions.count, 0)
        XCTAssertGreaterThanOrEqual(suggestions.firstMatch.frame.height, 44)
        XCTAssertTrue(app.buttons["閉じる"].isHittable)
        let apply = app.buttons["selfTimeApply"].firstMatch
        let dismiss = app.buttons["selfTimeDismiss"].firstMatch
        for _ in 0..<6 where !dismiss.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(apply.isHittable)
        XCTAssertTrue(dismiss.isHittable)
        XCTAssertGreaterThanOrEqual(dismiss.frame.minY, apply.frame.maxY)
        capture("natural-chat")
    }

    func testLargeTextKeepsChatEntryReachable() {
        app.launchArguments += ["-ui-testing-large-text"]
        launchHome()
        XCTAssertTrue(app.buttons["miraCompanionButton"].isHittable)
        app.buttons["miraCompanionButton"].tap()
        let input = app.descendants(matching: .any)["miraChatInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        XCTAssertTrue(input.isHittable)
        XCTAssertTrue(app.buttons["閉じる"].isHittable)
        let apply = app.buttons["selfTimeApply"].firstMatch
        for _ in 0..<6 where !apply.isHittable {
            app.scrollViews.firstMatch.swipeUp()
        }
        let dismiss = app.buttons["selfTimeDismiss"].firstMatch
        capture("large-text-chat")
        XCTAssertTrue(apply.isHittable)
        XCTAssertTrue(dismiss.isHittable)
        XCTAssertGreaterThanOrEqual(dismiss.frame.minY, apply.frame.maxY - 1)
    }

    func testColorsCanChangeAndSurviveRelaunch() {
        launchHome()
        openColorStyles()
        XCTAssertEqual(app.buttons["appColor-blue"].value as? String, "選択中")
        for style in ["rose", "lavender", "sage"] {
            let button = app.buttons["appColor-\(style)"]
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            button.tap()
            XCTAssertEqual(button.value as? String, "選択中")
            for other in ["blue", "sage", "rose", "lavender"] where other != style {
                XCTAssertNotEqual(app.buttons["appColor-\(other)"].value as? String, "選択中")
            }
        }
        capture("custom-sage-colors")

        app.terminate()
        app.launchArguments.removeAll { $0 == "-reset-demo" }
        launchHome()
        openColorStyles()
        XCTAssertEqual(app.buttons["appColor-sage"].value as? String, "選択中")
        app.buttons["appColor-blue"].tap()
        XCTAssertEqual(app.buttons["appColor-blue"].value as? String, "選択中")
        capture("blue-white-colors")
    }

    private func openColorStyles() {
        app.buttons["miraTab-settings"].tap()
        let colors = app.buttons["appColorSettings"].firstMatch
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        let navigationBar = app.navigationBars.firstMatch
        let settingsTab = app.buttons["miraTab-settings"]
        for _ in 0..<6 {
            if colors.exists {
                if colors.frame.minY >= navigationBar.frame.maxY + 8,
                   colors.frame.maxY <= settingsTab.frame.minY - 8 {
                    break
                }
                // SwiftUI may report a row under the navigation bar as
                // hittable. Bring the whole row back into the content area.
                if colors.frame.minY < navigationBar.frame.maxY + 8 {
                    let start = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
                    let end = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
                    start.press(forDuration: 0.05, thenDragTo: end)
                    continue
                }
            }
            app.swipeUp()
        }
        XCTAssertTrue(colors.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(colors.frame.minY, navigationBar.frame.maxY + 8)
        XCTAssertLessThanOrEqual(colors.frame.maxY, settingsTab.frame.minY - 8)
        colors.tap()
        if !app.buttons["appColor-blue"].waitForExistence(timeout: 5) {
            capture("color-picker-unreachable")
            print(app.debugDescription)
            XCTFail("Color choices must be exposed as buttons")
        }
    }

    private func launchHome() {
        app.launch()
        let recommended = app.buttons["おすすめを確認"]
        if recommended.waitForExistence(timeout: 5) {
            recommended.tap()
            let start = app.buttons["余白を置いて始める"]
            XCTAssertTrue(start.waitForExistence(timeout: 5))
            start.tap()
        }
        XCTAssertTrue(app.buttons["miraCompanionButton"].waitForExistence(timeout: 12))
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
