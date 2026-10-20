import XCTest

// Loop goals S1, S2, S4, S7 and U1/U2 (docs/loop-goals.md).
final class SelfTimeChatUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-reset-demo", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        completeOnboardingIfNeeded()
    }

    func testChatRequestShowsChipsAndAppliesInOneTap() throws {
        openCompanion()
        let apply = sendAndWaitForNewCard("来週は自分の時間を増やしたい", identifier: "selfTimeApply")
        let chips = app.buttons.matching(identifier: "selfTimeSlotChip")
        XCTAssertGreaterThan(chips.count, 0)
        XCTAssertTrue(app.staticTexts["あなたのお願い"].exists || app.descendants(matching: .any)["あなたのお願い"].exists)

        // Turning a chip off and on again changes what will be placed.
        if chips.count > 1 {
            let chip = chips.element(boundBy: chips.count - 1)
            chip.tap()
            XCTAssertEqual(chip.value as? String, "外した")
            chip.tap()
            XCTAssertEqual(chip.value as? String, "置く")
        }

        // U1: one tap after Mira answers. U2: no confirmation dialog.
        apply.tap()
        XCTAssertEqual(app.alerts.count, 0)
        let undo = app.buttons.matching(identifier: "selfTimeUndo").firstMatch
        require(undo, "undo chip after applying")
        undo.tap()
        XCTAssertEqual(app.alerts.count, 0)
        require(app.staticTexts["取り消しました"], "undone status")
    }

    func testChatRequestCanBeDismissed() throws {
        openCompanion()
        let dismiss = sendAndWaitForNewCard("来週は自分の時間を増やしたい", identifier: "selfTimeDismiss")
        dismiss.tap()
        XCTAssertEqual(app.alerts.count, 0)
        require(app.staticTexts["見送りました"], "dismissed status")
    }

    func testProactiveSuggestionIsReadableFromTheCompanion() throws {
        let companion = app.buttons["miraCompanionButton"]
        require(companion, "companion", timeout: 12)
        let hasSuggestion = app.buttons["提案を見る"].exists || app.staticTexts["来週の自分の時間、提案があるにゃ"].exists
        companion.tap()
        require(app.descendants(matching: .any)["miraChatInput"], "chat input")
        if hasSuggestion {
            require(app.staticTexts["chatProactiveText"].firstMatch, "proactive message")
            XCTAssertTrue(app.buttons["selfTimeApply"].firstMatch.exists)
        }
    }

    func testWeeklyReviewSatisfactionIsOneTap() throws {
        openTab("マイ余白")
        let card = app.descendants(matching: .any)["weeklyReviewCard"]
        require(card, "weekly review card")
        let good = app.buttons["satisfaction-3"]
        scrollUntilHittable(good)
        good.tap()
        XCTAssertTrue(app.buttons["satisfaction-3"].isSelected)
        XCTAssertEqual(app.alerts.count, 0)
    }

    func testFriendShareOffersText() throws {
        let toggle = app.buttons["friendViewToggle"]
        scrollUntilHittable(toggle)
        require(toggle, "friend view toggle", timeout: 8)
        toggle.tap()
        let text = app.buttons["friendShareText"]
        scrollUntilHittable(text)
        require(text, "share as text")
    }

    // MARK: Helpers

    private func openTab(_ title: String) {
        if app.tabBars.buttons[title].exists {
            app.tabBars.buttons[title].tap()
        } else {
            let floating = app.buttons[title].firstMatch
            require(floating, "tab \(title)")
            floating.tap()
        }
    }

    private func openCompanion() {
        let companion = app.buttons["miraCompanionButton"]
        require(companion, "companion", timeout: 12)
        companion.tap()
        require(app.descendants(matching: .any)["miraChatInput"], "chat input")
    }

    private func sendChat(_ text: String) {
        let input = app.descendants(matching: .any)["miraChatInput"]
        input.tap()
        input.typeText(text)
        app.buttons["miraChatSend"].tap()
    }

    /// A proactive card may already be in the chat, so wait for the one this message adds.
    private func sendAndWaitForNewCard(_ text: String, identifier: String) -> XCUIElement {
        let query = app.buttons.matching(identifier: identifier)
        let before = query.count
        sendChat(text)
        let deadline = Date().addingTimeInterval(20)
        while query.count <= before, Date() < deadline {
            _ = query.element(boundBy: before).waitForExistence(timeout: 1)
        }
        let element = query.element(boundBy: before)
        require(element, "\(identifier) on the new self-time card", timeout: 1)
        return element
    }

    private func scrollUntilHittable(_ element: XCUIElement) {
        var attempts = 0
        while !(element.exists && element.isHittable), attempts < 5 {
            app.swipeUp()
            attempts += 1
        }
    }

    private func require(_ element: XCUIElement, _ label: String, timeout: TimeInterval = 6) {
        if !element.waitForExistence(timeout: timeout) {
            XCTFail("missing \(label)\n\(app.debugDescription.prefix(5000))")
        }
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
}
