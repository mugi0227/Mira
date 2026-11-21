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
        XCTAssertTrue(companion.isHittable)
        XCTAssertLessThanOrEqual(companion.frame.maxY, calendar.frame.minY - 16)
        XCTAssertLessThanOrEqual(calendar.frame.maxY, scroll.frame.maxY)
        XCTAssertGreaterThanOrEqual(scroll.frame.maxY - calendar.frame.maxY, 7)
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
        XCTAssertTrue(summary.isHittable)
        let pills = summary.descendants(matching: .any).matching(identifier: "homeGoalPill")
        XCTAssertEqual(pills.count, 3)
        for index in 0..<pills.count {
            let pill = pills.element(boundBy: index)
            XCTAssertTrue(pill.isHittable)
            XCTAssertGreaterThanOrEqual(pill.frame.minX - app.frame.minX, 20)
            XCTAssertGreaterThanOrEqual(app.frame.maxX - pill.frame.maxX, 20)
            XCTAssertLessThanOrEqual(pill.frame.maxY + 20, scroll.frame.maxY)
        }
        let card = app.descendants(matching: .any)["homeNextStepCard"].firstMatch
        XCTAssertLessThanOrEqual(card.frame.maxY + 20, scroll.frame.maxY)
        XCTAssertFalse(card.frame.intersects(app.buttons["miraCompanionButton"].frame))
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
        let september = app.descendants(matching: .any)["homeMonthHeading"].firstMatch
        XCTAssertTrue(september.waitForExistence(timeout: 5))
        XCTAssertEqual(september.label, "2026年9月")
        app.buttons["次の月"].tap()
        XCTAssertEqual(september.label, "2026年10月")
        app.buttons["前の月"].tap()
        XCTAssertEqual(september.label, "2026年9月")
        // A date text's accessibility frame can expand over its event chips.
        // The explicit header button has its own, non-overlapping hit target.
        let dayHeader = app.buttons["calendar-date-2026-09-02"]
        XCTAssertTrue(dayHeader.isHittable)
        dayHeader.tap()
        XCTAssertTrue(app.buttons["この日に予定を追加"].waitForExistence(timeout: 5))
        capture("rounded-day")
    }

    func testHomeScrollKeepsHeaderClearAndViewportFixed() {
        launchHome()
        let scroll = app.scrollViews["homeScroll"]
        let statusBar = XCUIApplication(bundleIdentifier: "com.apple.springboard").statusBars.firstMatch
        XCTAssertTrue(scroll.exists)
        XCTAssertTrue(statusBar.exists)
        let viewport = scroll.frame
        let heading = app.descendants(matching: .any)["homeMonthHeading"].firstMatch
        let initialHeadingY = heading.frame.minY
        XCTAssertGreaterThanOrEqual(initialHeadingY, statusBar.frame.maxY)
        let calendar = app.descendants(matching: .any)["monthCalendar"].firstMatch
        let initialCalendarY = calendar.frame.minY

        // The calendar's event chips support dragging. Start in the screen
        // gutter so a busy Simulator cannot turn this into an event drag.
        let bottomGutter = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.9))
        let topGutter = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.1))
        bottomGutter.press(forDuration: 0.01, thenDragTo: topGutter)

        XCTAssertEqual(scroll.frame.minY, viewport.minY, accuracy: 1)
        // Lazy day cells may leave the accessibility tree when off-screen.
        // The calendar container remains measurable throughout the scroll.
        XCTAssertLessThan(calendar.frame.minY, initialCalendarY)
        XCTAssertFalse(app.buttons["miraCompanionButton"].isHittable)
        XCTAssertEqual(scroll.frame.maxY, viewport.maxY, accuracy: 1)
        // UIKit includes the top content inset in the scroll's accessibility
        // frame. The screenshot verifies the rendered safe-area fade as well.
        capture("calendar-scrolled-safe-area")
        topGutter.press(forDuration: 0.01, thenDragTo: bottomGutter)
        XCTAssertEqual(heading.frame.minY, initialHeadingY, accuracy: 1)
        capture("calendar-returned-header")
    }

    func testCompactCalendarOverflowOpensAllEventsForTheDay() {
        app.launchArguments += ["-friend-share-test"]
        launchHome()
        app.buttons["calendar-date-2026-09-02"].tap()
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

        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["前の月"].tap()
        XCTAssertEqual(app.descendants(matching: .any)["homeMonthHeading"].firstMatch.label, "2026年8月")
        app.buttons["friendViewToggle"].tap()
        app.buttons["friendRecipientPicker"].tap()
        let recipient = app.buttons["はる"]
        if !recipient.waitForExistence(timeout: 3) { app.buttons["friendRecipientPicker"].tap() }
        XCTAssertTrue(recipient.waitForExistence(timeout: 5), app.debugDescription)
        recipient.tap()
        app.buttons["friendLevelPicker"].tap()
        app.buttons["予定名まで"].tap()

        // August spans six weeks; September 2 is in its last row. Shared
        // calendars cannot open a day, so keep the normal two preview rows.
        let day = app.buttons["calendar-day-2026-09-02"].firstMatch
        let work = day.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "仕事")).firstMatch
        for _ in 0..<4 where !work.isHittable { app.scrollViews["homeScroll"].swipeUp() }
        XCTAssertTrue(work.isHittable, app.debugDescription)
        XCTAssertTrue(work.label.contains("9–18"))
        XCTAssertEqual(day.staticTexts.matching(identifier: "friendDayContent").count, 2)
        capture("compact-friend-calendar-two-previews")
    }

    func testToastLeavesMonthControlsReachable() throws {
        try assertToastLayout(theme: "pixelCat")
    }

    func testSilhouetteToastLeavesMonthControlsReachable() throws {
        try assertToastLayout(theme: "silhouetteCat")
    }

    private func assertToastLayout(theme: String) throws {
        let themeIndex = try XCTUnwrap(app.launchArguments.firstIndex(of: "-ui-theme"))
        app.launchArguments[themeIndex + 1] = theme
        app.launchArguments += ["-ui-testing-persistent-toast"]
        launchHome()
        let calendarPermission = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            .buttons.matching(NSPredicate(format: "label IN %@", ["Allow Full Access", "フルアクセスを許可"])).firstMatch
        if calendarPermission.waitForExistence(timeout: 2) { calendarPermission.tap() }

        let toast = app.staticTexts["appToast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 5))
        let lastRow = app.descendants(matching: .any)["calendar-day-2026-09-30"].firstMatch
        let tabs = app.descendants(matching: .any)["miraTabBar"].firstMatch
        // Existence can precede the toast's bottom transition and safe-area
        // layout settling, especially after dismissing the permission dialog.
        let toastSettled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let frame = toast.frame
            return !frame.isEmpty && frame.maxY <= tabs.frame.minY && !frame.intersects(lastRow.frame)
        }, object: toast)
        XCTAssertEqual(XCTWaiter.wait(for: [toastSettled], timeout: 5), .completed,
                       "Toast \(toast.frame) must settle clear of the last row \(lastRow.frame) and tabs \(tabs.frame)")
        let toastFrame = toast.frame
        let calendar = app.descendants(matching: .any)["monthCalendar"].firstMatch
        XCTAssertEqual(toastFrame.minX, calendar.frame.minX, accuracy: 1)
        let month = theme == "rounded"
            ? app.staticTexts["2026年9月"]
            : app.descendants(matching: .any)["homeMonthHeading"].firstMatch
        XCTAssertFalse(month.frame.intersects(toastFrame))
        for label in ["前の月", "次の月", "追加メニュー"] {
            let button = app.buttons[label]
            XCTAssertTrue(button.isHittable)
            XCTAssertFalse(button.frame.intersects(toastFrame))
        }
        let monthFrame = month.frame
        let lastRowFrame = lastRow.frame
        let tabFrame = tabs.frame
        XCTAssertLessThanOrEqual(lastRowFrame.maxY, tabFrame.minY)
        XCTAssertLessThanOrEqual(lastRowFrame.maxY, app.scrollViews["homeScroll"].frame.maxY)
        XCTAssertFalse(lastRowFrame.intersects(toastFrame), "Last row \(lastRowFrame) must not intersect toast \(toastFrame)")
        XCTAssertLessThanOrEqual(toastFrame.maxY, tabFrame.minY)
        XCTAssertFalse(toastFrame.intersects(app.buttons["miraCompanionButton"].frame))
        capture("floating-toast-\(theme)")
        app.buttons["次の月"].tap()
        XCTAssertEqual(month.label, "2026年10月")
        XCTAssertTrue(toast.exists)
        app.buttons["前の月"].tap()
        app.terminate()
        app.launchArguments.removeAll { $0 == "-reset-demo" || $0 == "-ui-testing-persistent-toast" }
        launchHome()
        let hidden = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: toast)
        XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 8), .completed)
        XCTAssertEqual(month.frame.minY, monthFrame.minY, accuracy: 1)
        XCTAssertEqual(lastRow.frame.maxY, lastRowFrame.maxY, accuracy: 1)
        XCTAssertEqual(tabs.frame.minY, tabFrame.minY, accuracy: 1)
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
        if !app.launchArguments.contains("-ui-testing-persistent-toast") {
            // Completing onboarding briefly shows a banner that moves Home.
            // Measure and tap only after that real, transient layout is gone.
            let toastGone = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"),
                object: app.staticTexts["appToast"]
            )
            XCTAssertEqual(XCTWaiter.wait(for: [toastGone], timeout: 5), .completed)
        }
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
