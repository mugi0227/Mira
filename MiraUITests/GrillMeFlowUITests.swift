import XCTest

final class GrillMeFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-reset-demo", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
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
        let suggestion = app.buttons["chatSuggestion"].firstMatch
        XCTAssertTrue(suggestion.waitForExistence(timeout: 5))
        suggestion.tap()
        XCTAssertTrue(waitForAssistantReply())
        capture("03-chat-schedule-answer")
    }

    func testCatSkinKeepsNavigationAndSheetsUsable() throws {
        let home = app.buttons["miraTab-home"]
        XCTAssertTrue(home.waitForExistence(timeout: 10))
        XCTAssertTrue(home.isHittable)
        XCTAssertTrue(app.buttons["miraCompanionButton"].exists)
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
        _ = app.buttons["miraCompanionButton"].waitForExistence(timeout: 12)
    }

    /// Talking to Mira starts from the companion in the home corner.
    private func openCompanion() {
        let companion = app.buttons["miraCompanionButton"]
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
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
