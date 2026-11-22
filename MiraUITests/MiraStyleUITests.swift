import XCTest

final class MiraStyleUITests: XCTestCase {
    func testNewItemFormClearsDraftDeleteButton() {
        app.launchArguments = ["-ui-testing", "-reset-demo", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        launchHome()
        app.buttons["追加メニュー"].tap()
        app.buttons["予定・余白を追加"].tap()
        let memo = app.switches["時間を取らない予定"]
        XCTAssertTrue(memo.waitForExistence(timeout: 5))
        memo.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let discard = app.buttons["下書きを削除"]
        XCTAssertTrue(discard.isHittable)
        capture("event-form-rest")
        for _ in 0..<3 { app.swipeUp() }
        let calendarLegend = app.descendants(matching: .any)["eventRoomLegend"].firstMatch
        XCTAssertTrue(calendarLegend.isHittable)
        XCTAssertLessThan(calendarLegend.frame.maxY, discard.frame.minY)
        capture("event-form-max-scroll")
        for _ in 0..<3 where !app.segmentedControls.buttons["余白"].isHittable { app.swipeDown() }
        app.segmentedControls.buttons["余白"].tap()
        capture("margin-form-rest")
        for _ in 0..<3 { app.swipeUp() }
        let duration = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "所要時間：")).firstMatch
        XCTAssertTrue(duration.isHittable)
        XCTAssertLessThan(duration.frame.maxY, discard.frame.minY)
        capture("margin-form-max-scroll")
    }

    func testCreateNonOccupyingMemo() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing", "-reset-demo", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        let next = app.buttons["おすすめを確認"]
        if next.waitForExistence(timeout: 4) {
            next.tap()
            let start = app.buttons["余白を置いて始める"]
            XCTAssertTrue(start.waitForExistence(timeout: 3))
            start.tap()
        }
        let menu = app.buttons["追加メニュー"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        menu.tap()
        app.buttons["予定・余白を追加"].tap()
        let title = app.textFields["例：友達とご飯"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        let sheetBar = app.navigationBars["予定を追加"]
        sheetBar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)))
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        XCTAssertTrue(menu.isHittable)
        XCTAssertFalse(app.buttons["下書き一覧"].exists)
        menu.tap()
        app.buttons["予定・余白を追加"].tap()
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        let memoTitle = "家族と友だちの長い出張予定を残すためのメモ"
        title.typeText(memoTitle)
        title.typeText("\n")
        let toggle = app.switches["時間を取らない予定"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        expectation(for: NSPredicate(format: "value == '1'"), evaluatedWith: toggle)
        waitForExpectations(timeout: 3)
        let form = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        form.name = "memo-form-toggle-on"
        form.lifetime = .keepAlways
        add(form)
        for _ in 0..<3 { app.swipeUp() }
        let formBottom = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        formBottom.name = "memo-form-max-scroll"
        formBottom.lifetime = .keepAlways
        add(formBottom)
        app.navigationBars["予定を追加"].buttons["追加"].tap()
        XCTAssertTrue(menu.waitForExistence(timeout: 8))
        let memo = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", memoTitle)).firstMatch
        XCTAssertTrue(memo.waitForExistence(timeout: 5))
        let calendar = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        calendar.name = "memo-calendar-before-conversion"
        calendar.lifetime = .keepAlways
        add(calendar)
        app.buttons["calendar-date-2026-09-01"].tap()
        let timeBar = app.buttons["inlineDayTimeBar"]
        XCTAssertTrue(timeBar.waitForExistence(timeout: 5))
        timeBar.tap()
        XCTAssertTrue(app.buttons["この日に予定を追加"].waitForExistence(timeout: 5))
        let memoRows = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", memoTitle + "、"))
        let memoRow = memoRows.firstMatch
        XCTAssertTrue(memoRow.waitForExistence(timeout: 5))
        XCTAssertEqual(memoRows.count, 1)
        for _ in 0..<4 where !memoRow.isHittable { app.swipeDown() }
        XCTAssertTrue(memoRow.isHittable)
        XCTAssertTrue(memoRow.label.contains("18:00–20:00"))
        XCTAssertTrue(memoRow.label.hasSuffix("、メモ"))
        let day = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        day.name = "memo-day"
        day.lifetime = .keepAlways
        add(day)
        app.scrollViews.firstMatch.swipeUp()
        XCTAssertTrue(memoRow.isHittable)
        XCTAssertEqual(memoRows.count, 1)
        memoRow.tap()
        let occupancy = app.buttons["eventOccupiesTime"]
        XCTAssertTrue(occupancy.waitForExistence(timeout: 5))
        XCTAssertEqual(occupancy.value as? String, "オフ")
        let detail = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        detail.name = "memo-detail"
        detail.lifetime = .keepAlways
        add(detail)
        occupancy.tap()
        let approve = app.buttons["影響を承認して変更"]
        XCTAssertTrue(approve.waitForExistence(timeout: 5))
        let cancel = app.buttons["キャンセル"]
        if cancel.exists {
            cancel.tap()
        } else {
            app.buttons["閉じる"].firstMatch.tap()
        }
        XCTAssertEqual(occupancy.value as? String, "オフ")
        occupancy.tap()
        XCTAssertTrue(approve.waitForExistence(timeout: 5))
        approve.tap()
        XCTAssertEqual(occupancy.value as? String, "オン", app.debugDescription)
        occupancy.tap()
        XCTAssertEqual(occupancy.value as? String, "オフ")
        app.buttons["閉じる"].tap()
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        capture("memo-calendar")
    }

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-demo", "-ui-theme", "pixelCat", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
    }

    func testCenterChatReturnsToSelectedTab() {
        app.launchArguments = ["-ui-testing", "-reset-demo", "-ui-theme", "softMinimal", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        launchHome()
        let bar = app.tabBars.firstMatch
        XCTAssertTrue(bar.exists)
        let chat = bar.buttons["チャット"]
        let orderedButtons = ["ホーム", "調整", "チャット", "マイ余白", "設定"]
        for (left, right) in zip(orderedButtons, orderedButtons.dropFirst()) {
            XCTAssertLessThan(bar.buttons[left].frame.midX, bar.buttons[right].frame.midX)
        }
        capture("centerchat-home")
        for tab in ["ホーム", "調整", "マイ余白", "設定"] {
            let selected = bar.buttons[tab]
            selected.tap()
            XCTAssertTrue(selected.isSelected)
            if tab == "調整" { capture("centerchat-adjustments") }
            XCTAssertTrue(chat.isHittable)
            chat.tap()
            let input = app.descendants(matching: .any)["miraChatInput"]
            XCTAssertTrue(input.waitForExistence(timeout: 5))
            if tab == "ホーム" { capture("centerchat-sheet") }
            app.buttons["閉じる"].tap()
            XCTAssertTrue(chat.waitForExistence(timeout: 5))
            XCTAssertTrue(selected.isSelected)
        }
    }

    func testDisablingAssistantRestoresFourTabs() {
        app.launchArguments = ["-ui-testing", "-reset-demo", "-ui-theme", "softMinimal", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        launchHome()
        let bar = app.tabBars.firstMatch
        XCTAssertEqual(bar.buttons.count, 5)
        bar.buttons["設定"].tap()
        let toggle = app.switches["案内役を表示"]
        for _ in 0..<6 where !toggle.isHittable { app.swipeUp() }
        XCTAssertTrue(toggle.isHittable)
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertTrue(app.miraChatButton.waitForNonExistence(timeout: 5))
        XCTAssertEqual(bar.buttons.count, 4)
        for tab in ["ホーム", "調整", "マイ余白", "設定"] {
            XCTAssertTrue(bar.buttons[tab].isHittable)
        }
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        XCTAssertTrue(app.miraChatButton.waitForExistence(timeout: 5))
        XCTAssertEqual(bar.buttons.count, 5)
    }

    func testPendingChatRequestOpensSheet() {
        launchHome()
        app.terminate()
        app.launchArguments.removeAll { $0 == "-reset-demo" }
        app.launchArguments += ["-mira.open-chat.pending", "YES"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["miraChatInput"].waitForExistence(timeout: 12))
        app.buttons["閉じる"].tap()
        XCTAssertTrue(app.buttons["miraTab-home"].isSelected)
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
        let companion = app.miraChatButton
        XCTAssertTrue(companion.isHittable)
        XCTAssertGreaterThanOrEqual(companion.frame.minY, scroll.frame.maxY)
        let bottomOverflow = calendar.frame.maxY - scroll.frame.maxY + 7
        if bottomOverflow > 0 {
            let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.75))
            let end = start.withOffset(CGVector(dx: 0, dy: -bottomOverflow - 16))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        }
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
        XCTAssertFalse(card.frame.intersects(app.miraChatButton.frame))
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
        XCTAssertTrue(app.miraChatButton.isHittable)
        capture("rounded-home")
    }

    func testMonthControlsStillOpenADay() {
        launchHome()
        let september = app.descendants(matching: .any)["homeMonthHeading"].firstMatch
        XCTAssertTrue(september.waitForExistence(timeout: 5))
        XCTAssertEqual(september.label, "2026年9月、11件の予定")
        app.buttons["次の月"].tap()
        XCTAssertEqual(september.label, "2026年10月、4件の予定")
        app.buttons["前の月"].tap()
        XCTAssertEqual(september.label, "2026年9月、11件の予定")
        // A date text's accessibility frame can expand over its event chips.
        // The explicit header button has its own, non-overlapping hit target.
        let dayHeader = app.buttons["calendar-date-2026-09-02"]
        XCTAssertTrue(dayHeader.isHittable)
        dayHeader.tap()
        Thread.sleep(forTimeInterval: 1)
        app.buttons["inlineDayTimeBar"].tap()
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
        XCTAssertTrue(app.miraChatButton.isHittable)
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
        Thread.sleep(forTimeInterval: 1)
        app.buttons["inlineDayTimeBar"].tap()
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
        app.buttons["calendar-date-2026-09-02"].tap()
        Thread.sleep(forTimeInterval: 1)

        let overflow = app.buttons["calendar-overflow-2026-09-02"]
        XCTAssertTrue(overflow.waitForExistence(timeout: 5))
        XCTAssertTrue(overflow.isHittable)
        overflow.tap()
        Thread.sleep(forTimeInterval: 1)
        app.buttons["inlineDayTimeBar"].tap()
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "仕事、")).firstMatch.exists)
        XCTAssertTrue(dinner.exists)
        capture("compact-calendar-day-events")

        app.terminate()
        app.launchArguments.removeAll { $0 == "-reset-demo" }
        launchHome()
        let previousMonth = app.buttons.matching(NSPredicate(format: "label == %@", "前の月")).firstMatch
        waitUntilStableAndHittable(previousMonth)
        app.buttons["前の月"].tap()
        let heading = app.descendants(matching: .any)["homeMonthHeading"].firstMatch
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label BEGINSWITH %@", "2026年8月、"), object: heading
        )], timeout: 5), .completed)
        XCTAssertEqual(app.descendants(matching: .any)["homeMonthHeading"].firstMatch.label.components(separatedBy: "、").first, "2026年8月")
        Thread.sleep(forTimeInterval: 1)
        app.buttons["friendViewToggle"].tap()
        let recipientPicker = app.buttons["friendRecipientPicker"]
        waitUntilStableAndHittable(recipientPicker)
        recipientPicker.tap()
        let recipient = app.buttons["はる"]
        XCTAssertTrue(recipient.waitForExistence(timeout: 5), app.debugDescription)
        recipient.tap()
        let levelPicker = app.buttons["friendLevelPicker"]
        waitUntilStableAndHittable(levelPicker)
        levelPicker.tap()
        let titles = app.buttons["予定名まで"]
        XCTAssertTrue(titles.waitForExistence(timeout: 5))
        titles.tap()
        XCTAssertEqual(heading.label.components(separatedBy: "、").first, "2026年8月", "Friend picker interactions must not change the displayed month")

        // August spans six weeks; September 2 is in its last row. Shared
        // calendars cannot open a day, so keep the normal two preview rows.
        let day = app.buttons["calendar-day-2026-09-02"].firstMatch
        let work = day.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "仕事")).firstMatch
        let home = app.scrollViews["homeScroll"]
        for _ in 0..<8 {
            if day.exists && work.exists && work.isHittable { break }
            home.swipeUp()
        }
        XCTAssertTrue(day.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(work.waitForExistence(timeout: 5), app.debugDescription)
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
        let lastRow = app.buttons["calendar-date-2026-09-30"]
        let tabs = app.descendants(matching: .any)["miraTabBar"].firstMatch
        XCTAssertTrue(lastRow.waitForExistence(timeout: 5))
        XCTAssertTrue(tabs.waitForExistence(timeout: 5))
        // Existence can precede the toast's bottom transition and safe-area
        // layout settling, especially after dismissing the permission dialog.
        let toastSettled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let frame = toast.frame
            return !frame.isEmpty && frame.maxY <= tabs.frame.minY && !frame.intersects(lastRow.frame)
        }, object: toast)
        XCTAssertEqual(XCTWaiter.wait(for: [toastSettled], timeout: 5), .completed,
                       "Toast \(toast.frame) must settle clear of the last row \(lastRow.frame) and tabs \(tabs.frame)")
        XCTAssertTrue(lastRow.isHittable)
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
        XCTAssertFalse(toastFrame.intersects(app.miraChatButton.frame))
        capture("floating-toast-\(theme)")
        app.buttons["次の月"].tap()
        XCTAssertEqual(month.label.components(separatedBy: "、").first, "2026年10月")
        XCTAssertTrue(toast.exists)
        app.buttons["前の月"].tap()
        let restoredLayout = NSPredicate { _, _ in
            guard month.exists, lastRow.exists, tabs.exists else { return false }
            return month.label.components(separatedBy: "、").first == "2026年9月"
                && abs(month.frame.minY - monthFrame.minY) <= 1
                && abs(lastRow.frame.maxY - lastRowFrame.maxY) <= 1
                && abs(tabs.frame.minY - tabFrame.minY) <= 1
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: restoredLayout, object: app)], timeout: 10), .completed)
        app.terminate()
        app.launchArguments.removeAll { $0 == "-reset-demo" || $0 == "-ui-testing-persistent-toast" }
        launchHome()
        let hidden = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: toast)
        XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 8), .completed)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: restoredLayout, object: app)], timeout: 10), .completed)
        XCTAssertEqual(month.frame.minY, monthFrame.minY, accuracy: 1)
        XCTAssertEqual(lastRow.frame.maxY, lastRowFrame.maxY, accuracy: 1)
        XCTAssertEqual(tabs.frame.minY, tabFrame.minY, accuracy: 1)
    }

    func testChatUsesNaturalVoiceAndAccessibleControls() {
        launchHome()
        app.miraChatButton.tap()
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
        XCTAssertTrue(app.miraChatButton.isHittable)
        app.miraChatButton.tap()
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
        XCTAssertTrue(app.miraChatButton.waitForExistence(timeout: 12))
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

    private func waitUntilStableAndHittable(_ element: XCUIElement) {
        var previousFrame: CGRect?
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard element.exists, element.isHittable else { return false }
            let frame = element.frame
            defer { previousFrame = frame }
            guard !frame.isEmpty, let previousFrame else { return false }
            return abs(frame.minX - previousFrame.minX) <= 0.5
                && abs(frame.minY - previousFrame.minY) <= 0.5
                && abs(frame.width - previousFrame.width) <= 0.5
                && abs(frame.height - previousFrame.height) <= 0.5
        }, object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 10), .completed, app.debugDescription)
    }
}
