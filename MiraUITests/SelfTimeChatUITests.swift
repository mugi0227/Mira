import XCTest

// Loop goals S1, S2, S4, S7 and U1/U2 (docs/loop-goals.md).
final class SelfTimeChatUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-reset-demo", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        if name.contains("testMarkdownAssistantReply") { app.launchArguments.append("-ui-markdown-reply") }
        app.launch()
        completeOnboardingIfNeeded()
    }

    func testMarkdownAssistantReply() throws {
        openCompanion()
        sendChat("今月ちゃんと休めてる？")
        let reply = app.staticTexts.matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "chatAssistantText", "読書")).firstMatch
        require(reply, "rendered markdown reply", timeout: 20)
        XCTAssertFalse(reply.label.contains("**"))
        XCTAssertFalse(reply.label.contains("* "))
        XCTAssertTrue(reply.label.contains("•"))
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "chat-rendered-markdown"
        attachment.lifetime = .keepAlways
        add(attachment)
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

    func testTomorrowDinnerShowsEventProposal() throws {
        openCompanion()
        sendChat("明日の19時に友達と夕食を追加して")
        require(app.buttons["chatApplyCard"].firstMatch, "event proposal", timeout: 20)
        XCTAssertTrue(app.staticTexts["友達と夕食"].firstMatch.exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "うまく考えられなかった")).firstMatch.exists)
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "tomorrow-dinner-proposal"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testOverlappingProposalNamesExistingEvent() throws {
        openCompanion()
        sendChat("明日の10時に友達と夕食を追加して")
        require(app.buttons["chatApplyCard"].firstMatch, "event proposal", timeout: 20)
        let warning = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "『仕事』", "重なっています")).firstMatch
        require(warning, "named work conflict")
        XCTAssertTrue(warning.label.contains("09:00〜18:00"))
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "named-conflict-proposal"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testProposalDayTimelineOpensConflictingEvent() throws {
        openCompanion()
        sendChat("明日の10時に友達と夕食を追加して")
        let showDay = app.buttons["proposal.showDay"].firstMatch
        require(showDay, "day timeline entry")
        showDay.tap()
        let block = app.descendants(matching: .any)["proposal.timelineBlock"].firstMatch
        require(block, "proposal overlay")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.49))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)))
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "proposal-day-timeline-large"
        attachment.lifetime = .keepAlways
        add(attachment)
        let row = app.buttons["proposal.conflict.仕事"].firstMatch
        require(row, "work conflict row")
        row.tap()
        require(app.navigationBars["詳細"], "event details")
        require(app.staticTexts["仕事"].firstMatch, "work event title")
    }

    func testProactiveSuggestionIsReadableFromTheCompanion() throws {
        let companion = app.buttons["miraCompanionButton"]
        require(companion, "companion", timeout: 12)
        let hasSuggestion = app.buttons["提案を見る"].exists || app.staticTexts["来週の自分の時間、提案があります"].exists
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
        XCTAssertTrue(app.staticTexts["appToast"].waitForNonExistence(timeout: 5))
        let toggle = app.buttons["friendViewToggle"]
        scrollUntilHittable(toggle)
        require(toggle, "friend view toggle", timeout: 8)
        toggle.tap()
        let text = app.buttons["friendShareText"]
        scrollUntilHittable(text)
        require(text, "share as text")
    }

    func testHomeScrollEndsJustAboveCompanion() {
        let companion = app.buttons["miraCompanionButton"]
        require(companion, "companion", timeout: 12)
        let home = app.scrollViews["homeScroll"]
        require(home, "home scroll")
        home.swipeUp(velocity: .fast)
        home.swipeUp(velocity: .fast)

        let progress = app.descendants(matching: .any)["homeGoalSummary"].firstMatch
        require(progress, "monthly progress summary")
        captureScrollState("home-scroll-end")
        let gap = companion.frame.minY - progress.frame.maxY
        XCTAssertGreaterThanOrEqual(gap, 0)
        XCTAssertLessThanOrEqual(gap, 48, "Home should not scroll into unused space above Mira")
        let tabGap = app.buttons["miraTab-home"].frame.minY - companion.frame.maxY
        XCTAssertGreaterThanOrEqual(tabGap, 0)
        XCTAssertLessThanOrEqual(tabGap, 32, "The tab bar already reserves its own space")
    }

    func testLatestChatActionStaysAboveKeyboardAndComposer() {
        openCompanion()
        sendChat("明日の19時に友達と夕食を追加して")
        let action = app.buttons["chatApplyCard"].firstMatch
        require(action, "latest reply action", timeout: 20)
        let input = app.descendants(matching: .any)["miraChatInput"]
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        captureScrollState("chat-reply-above-composer")
        XCTAssertTrue(action.isHittable)
        XCTAssertLessThanOrEqual(action.frame.maxY, input.frame.minY)
    }

    func testEditingAnOlderChatCardDoesNotJumpToLatest() {
        openCompanion()
        let firstTitle = "友達と夕食"
        for (request, title) in [
            ("明日の19時に友達と夕食を追加して", firstTitle),
            ("明日の20時に友達と映画を追加して", "友達と映画"),
            ("明日の21時に友達と会う予定を追加して", "友達と会う予定")
        ] {
            sendChat(request)
            require(app.staticTexts[title].firstMatch, "proposal for \(title)", timeout: 20)
        }

        let history = app.scrollViews["miraChatTranscript"]
        require(history, "chat transcript")
        let firstProposal = app.staticTexts[firstTitle].firstMatch
        let firstDismiss = app.buttons.matching(identifier: "やめる").firstMatch
        for _ in 0..<5 where !firstProposal.isHittable || !firstDismiss.isHittable { history.swipeDown() }
        XCTAssertTrue(firstProposal.isHittable)
        XCTAssertTrue(firstDismiss.isHittable)
        firstDismiss.tap()

        let dismissed = app.staticTexts["見送りました"]
        require(dismissed, "older card's dismissed status")
        let input = app.descendants(matching: .any)["miraChatInput"]
        XCTAssertLessThan(dismissed.frame.maxY, input.frame.minY)
        XCTAssertGreaterThan(dismissed.frame.minY, app.navigationBars["Mira"].frame.maxY)
    }

    func testMarginsScrollEndsNearTabs() {
        openTab("マイ余白")
        let margins = app.scrollViews.firstMatch
        for _ in 0..<5 { margins.swipeUp(velocity: .fast) }

        let lastMonth = app.buttons["12月"]
        require(lastMonth, "last month shortcut")
        captureScrollState("margins-scroll-end")
        let gap = app.buttons["miraTab-margins"].frame.minY - lastMonth.frame.maxY
        XCTAssertGreaterThan(gap, 0)
        XCTAssertLessThan(gap, 75, "Margins should not scroll an extra tab bar's height")
    }

    func testSchedulingScrollEndsNearItsAction() {
        openTab("調整")
        captureScrollState("adjustments")
        app.buttons["日程を探す"].tap()
        let save = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "候補でOK")).firstMatch
        require(save, "scheduling action")
        let schedule = app.scrollViews.firstMatch
        for _ in 0..<5 { schedule.swipeUp(velocity: .fast) }

        let summary = app.otherElements["schedulingSelectedSummary"]
        require(summary, "candidate summary")
        captureScrollState("scheduling-scroll-end")
        let gap = save.frame.minY - summary.frame.maxY
        XCTAssertGreaterThan(gap, 0)
        XCTAssertLessThan(gap, 72, "The pinned action already reserves space below the candidates")
    }

    func testDayTimelineEndsNearTheFinalHour() {
        XCTAssertTrue(app.staticTexts["appToast"].waitForNonExistence(timeout: 5))
        let day = app.buttons["calendar-date-2026-09-03"]
        require(day, "an empty day on the demo calendar")
        day.tap()
        Thread.sleep(forTimeInterval: 1)
        app.buttons["inlineDayTimeBar"].tap()
        require(app.buttons["この日に予定を追加"], "day timeline")

        let timeline = app.scrollViews.firstMatch
        for _ in 0..<4 { timeline.swipeUp(velocity: .fast) }
        let lastHour = app.staticTexts["23:00"]
        require(lastHour, "last hour")
        captureScrollState("timeline-scroll-end")
        let tabTop = app.tabBars.firstMatch.exists ? app.tabBars.firstMatch.frame.minY : app.buttons["miraTab-home"].frame.minY
        let gap = tabTop - lastHour.frame.maxY
        XCTAssertGreaterThan(gap, 0)
        XCTAssertLessThan(gap, 110, "The final hour should not be followed by another hour of blank space")
    }

    // MARK: Helpers

    private func captureScrollState(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

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
