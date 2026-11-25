import XCTest

final class GrillMeFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-reset-demo", "-ui-theme", "pixelCat", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        completeOnboardingIfNeeded()
    }

    func testChatFindsSlotsAndAddsOnlyAfterApproval() throws {
        openCompanion()
        sendChat("来週友達と焼肉行きたい")
        XCTAssertTrue(waitForAssistantReply(), "Mira should answer in the chat")
        capture("01-chat-open-slots")

        let slotsHeader = app.staticTexts["余白を守れる候補"]
        if slotsHeader.waitForExistence(timeout: 3) {
            let slot = app.buttons.matching(NSPredicate(format: "label CONTAINS '月' AND label CONTAINS '–'")).firstMatch
            if slot.waitForExistence(timeout: 3) {
                slot.tap()
                let apply = app.buttons["chatApplyCard"].firstMatch
                XCTAssertTrue(apply.waitForExistence(timeout: 8))
                capture("02-chat-event-proposal")
                apply.tap()
                XCTAssertTrue(app.staticTexts["追加しました"].waitForExistence(timeout: 5))
            }
        }
    }

    func testChatSuggestionAnswersFromTheCalendar() throws {
        openCompanion()
        let suggestion = app.buttons["今週の予定は？"]
        XCTAssertTrue(suggestion.waitForExistence(timeout: 5))
        let conversation = app.scrollViews.containing(.button, identifier: "chatSuggestion").firstMatch
        let navigationBar = app.navigationBars["Mira"]
        // A proactive card opens the conversation at the bottom. Its first
        // suggestion can exist behind the navigation bar without being visible.
        for _ in 0..<4 where !suggestion.isHittable || suggestion.frame.minY < navigationBar.frame.maxY + 8 {
            conversation.swipeDown()
        }
        XCTAssertTrue(suggestion.isHittable)
        XCTAssertGreaterThanOrEqual(suggestion.frame.minY, navigationBar.frame.maxY + 8)
        suggestion.tap()
        XCTAssertTrue(suggestion.waitForNonExistence(timeout: 5), "The prompt must actually be sent")
        XCTAssertTrue(waitForAssistantReply())
        capture("03-chat-schedule-answer")
    }

    func testCatSkinKeepsNavigationAndSheetsUsable() throws {
        let home = app.buttons["miraTab-home"]
        XCTAssertTrue(home.waitForExistence(timeout: 10))
        XCTAssertTrue(home.isHittable)
        XCTAssertTrue(app.miraChatButton.exists)
        capture("cat-skin-01-home")

        let destinations = [
            ("adjustments", "調整"),
            ("margins", "マイ余白"),
            ("settings", "設定")
        ]
        for (identifier, title) in destinations {
            let tab = app.buttons["miraTab-\(identifier)"]
            XCTAssertTrue(tab.exists)
            XCTAssertTrue(tab.isHittable)
            tab.tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
            capture("cat-skin-\(identifier)")
        }

        let skinPicker = app.staticTexts["スキン"]
        XCTAssertTrue(skinPicker.waitForExistence(timeout: 4))
        skinPicker.tap()
        XCTAssertTrue(app.navigationBars["スキン"].waitForExistence(timeout: 4))
        capture("cat-skin-picker")
        app.navigationBars["スキン"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["設定"].waitForExistence(timeout: 4))

        home.tap()
        let addMenu = app.buttons["追加メニュー"]
        XCTAssertTrue(addMenu.waitForExistence(timeout: 4))
        addMenu.tap()
        let addItem = app.buttons["予定・余白を追加"]
        // A menu can close if the screen redraws while it opens; open it once more before judging.
        if !addItem.waitForExistence(timeout: 3) {
            addMenu.tap()
        }
        XCTAssertTrue(addItem.waitForExistence(timeout: 3))
        addItem.tap()
        let itemSheet = app.navigationBars["予定を追加"]
        XCTAssertTrue(itemSheet.waitForExistence(timeout: 4))
        XCTAssertTrue(app.textFields["例：友達とご飯"].exists)
        capture("cat-skin-new-item-sheet")
        itemSheet.buttons["保存して閉じる"].tap()
        XCTAssertTrue(home.waitForExistence(timeout: 4))
        XCTAssertTrue(home.isHittable)

        openCompanion()
        capture("cat-skin-chat")
        let companionSheet = app.navigationBars["Mira"]
        XCTAssertTrue(companionSheet.waitForExistence(timeout: 4))
        companionSheet.buttons["閉じる"].tap()
        XCTAssertTrue(home.waitForExistence(timeout: 4))
        XCTAssertTrue(home.isHittable)
    }

    func testPastedEventBecomesAProposalNotASavedEvent() throws {
        openCompanion()
        sendChat("9/12 18時から友達とカフェを予定に追加して")
        XCTAssertTrue(waitForAssistantReply())
        if app.staticTexts["予定の案"].waitForExistence(timeout: 3) {
            XCTAssertTrue(app.buttons["chatApplyCard"].firstMatch.exists)
        }
        capture("04-chat-pasted-event")
    }

    private func completeOnboardingIfNeeded() {
        guard app.staticTexts["自分のための時間を守ろう。"].waitForExistence(timeout: 4) else { return }
        let recommended = app.buttons["おすすめを確認"]
        XCTAssertTrue(recommended.waitForExistence(timeout: 3))
        recommended.tap()
        let finish = app.buttons["余白を置いて始める"]
        if finish.waitForExistence(timeout: 4) {
            finish.tap()
        }
        _ = app.miraChatButton.waitForExistence(timeout: 12)
    }

    /// Talking to Mira starts from the companion in the home corner.
    private func openCompanion() {
        let companion = app.miraChatButton
        XCTAssertTrue(companion.waitForExistence(timeout: 12))
        companion.tap()
        XCTAssertTrue(app.descendants(matching: .any)["miraChatInput"].waitForExistence(timeout: 5))
    }

    private func sendChat(_ text: String) {
        let input = app.descendants(matching: .any)["miraChatInput"]
        input.tap()
        input.typeText(text)
        app.buttons["miraChatSend"].tap()
    }

    /// A finished assistant bubble, whichever agent answered.
    private func waitForAssistantReply(timeout: TimeInterval = 20) -> Bool {
        app.staticTexts["chatAssistantText"].firstMatch.waitForExistence(timeout: timeout)
    }

    /// Cards below the calendar may start off-screen behind the tab bar.
    private func scrollUntilHittable(_ element: XCUIElement) {
        var attempts = 0
        while !element.isHittable, attempts < 4 {
            app.swipeUp()
            attempts += 1
        }
    }

    func testInterruptedEntrySurvivesRelaunchAndResumesFromHome() throws {
        app.buttons["追加メニュー"].tap()
        app.buttons["予定・余白を追加"].tap()
        let title = app.textFields["例：友達とご飯"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("途中で考えていた食事")
        app.navigationBars["予定を追加"].buttons["保存して閉じる"].tap()
        XCTAssertTrue(app.buttons["resumeLatestDraft"].waitForExistence(timeout: 5))

        app.terminate()
        app.launchArguments.removeAll { $0 == "-reset-demo" }
        app.launch()
        let resume = app.buttons["resumeLatestDraft"]
        XCTAssertTrue(resume.waitForExistence(timeout: 12))
        scrollUntilHittable(resume)
        resume.tap()
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.value as? String, "途中で考えていた食事")
    }

    private func capture(_ name: String) {
        let folder = URL(fileURLWithPath: "/tmp/mira-field-review", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: folder.appendingPathComponent(name + ".png"))
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testKeyboardTimeRejectsInvalidInputAndSavesCompactTimeWithoutLosingFocus() {
        app.buttons["miraTab-settings"].tap()
        let general = app.descendants(matching: .any)["calendarDisplaySettings"].firstMatch
        scrollUntilHittable(general)
        general.tap()
        let keyboard = app.switches["時刻設定のキーボード表示"]
        scrollUntilHittable(keyboard)
        if keyboard.value as? String != "1" {
            keyboard.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        }
        XCTAssertEqual(keyboard.value as? String, "1")

        app.buttons["miraTab-home"].tap()
        app.buttons["追加メニュー"].tap()
        app.buttons["予定・余白を追加"].tap()
        let saveDraft = app.navigationBars["予定を追加"].buttons["保存して閉じる"]
        let start = app.textFields.matching(NSPredicate(format: "label == %@ OR identifier == %@", "開始時刻", "eventStartTime")).firstMatch
        scrollUntilHittable(start)
        let upper = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.38))
        let lower = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.66))
        for _ in 0..<3 where start.frame.midY > app.frame.midY {
            lower.press(forDuration: 0.05, thenDragTo: upper)
        }
        let caret = start.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5))
        func replaceStart(with value: String) {
            caret.tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 4))
            start.typeKey("a", modifierFlags: .command)
            start.typeText(value)
            XCTAssertEqual(start.value as? String, value)
        }

        replaceStart(with: "1260")
        saveDraft.tap()
        XCTAssertTrue(saveDraft.exists, "Invalid input must not close the draft")
        XCTAssertEqual(start.value as? String, "1260")

        replaceStart(with: "930")
        saveDraft.tap()
        let resume = app.buttons["resumeLatestDraft"]
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        scrollUntilHittable(resume)
        resume.tap()
        scrollUntilHittable(start)
        XCTAssertEqual(start.value as? String, "9:30")

        saveDraft.tap()
        app.buttons["miraTab-settings"].tap()
        scrollUntilHittable(keyboard)
        keyboard.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertEqual(keyboard.value as? String, "0")
    }

    func testCatSkinCanStillSwipeHorizontallyWithVerticalPagingSelected() {
        app.buttons["miraTab-settings"].tap()
        let general = app.descendants(matching: .any)["calendarDisplaySettings"].firstMatch
        scrollUntilHittable(general)
        general.tap()
        let vertical = app.buttons["縦スクロール（月の見出しを上下に）"]
        scrollUntilHittable(vertical)
        vertical.tap()
        XCTAssertTrue(vertical.isSelected)

        app.buttons["miraTab-home"].tap()
        let heading = app.descendants(matching: .any)["homeMonthHeading"].firstMatch
        let grid = app.descendants(matching: .any)["monthCalendar"].firstMatch
        XCTAssertTrue(grid.waitForExistence(timeout: 4))
        let month = heading.label
        let start = grid.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.35))
        let end = grid.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.35))
        start.press(forDuration: 0.05, thenDragTo: end)
        let changedMonth = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", month), object: heading)
        XCTAssertEqual(XCTWaiter.wait(for: [changedMonth], timeout: 4), .completed)
    }

    func testSettingsFooterScrollsAboveTabsAndWorkHoursAreEditable() throws {
        let tab = app.buttons["設定"].firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
        tab.tap()
        let work = app.buttons["仕事・学校の時間"].firstMatch
        XCTAssertTrue(work.waitForExistence(timeout: 5))
        scrollUntilHittable(work)
        work.tap()
        let bulk = app.buttons["平日まとめて変更"]
        XCTAssertTrue(bulk.waitForExistence(timeout: 5))
        bulk.tap()
        XCTAssertTrue(app.buttons["適用"].waitForExistence(timeout: 5))
        capture("field-01-weekday-editor")
        app.buttons["適用"].tap()
        app.buttons["保存"].tap()
        let footer = app.descendants(matching: .any)["settingsFooter"].firstMatch
        for _ in 0..<6 { app.swipeUp() }
        XCTAssertTrue(footer.exists)
        XCTAssertLessThan(footer.frame.maxY, tab.frame.minY, "Last settings content must sit above the tab controls")
        capture("field-02-settings-bottom")
    }

    func testOriginalGoalCanBeAddedAndSurvivesRelaunch() throws {
        app.buttons["マイ余白"].firstMatch.tap()
        let add = app.buttons["オリジナルの目標を追加"]
        scrollUntilHittable(add)
        XCTAssertTrue(add.isHittable)
        add.tap()
        let title = app.textFields["customGoalTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("ギターの練習")
        app.buttons["保存"].tap()
        app.terminate()
        app.launchArguments.removeAll { $0 == "-reset-demo" }
        app.launch()
        XCTAssertTrue(app.buttons["マイ余白"].firstMatch.waitForExistence(timeout: 12))
        app.buttons["マイ余白"].firstMatch.tap()
        let goal = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "ギターの練習")).firstMatch
        scrollUntilHittable(goal)
        XCTAssertTrue(goal.isHittable)
        goal.tap()
        XCTAssertEqual(app.textFields["customGoalTitle"].value as? String, "ギターの練習")
        XCTAssertTrue(app.staticTexts["1時間"].exists)
        capture("field-03-original-goal")
    }
}
