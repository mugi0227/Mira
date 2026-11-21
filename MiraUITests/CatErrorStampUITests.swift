import XCTest

final class CatErrorStampUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testOneLineFailureStamp() { checkFailure(theme: "onelineCat") }
    func testSilhouetteFailureStamp() { checkFailure(theme: "silhouetteCat") }
    func testPixelFailureStamp() { checkFailure(theme: "pixelCat") }

    func testLargeTextFailureStamp() {
        checkFailure(theme: "silhouetteCat", extra: ["-ui-testing-large-text"])
    }

    func testSuccessfulReplyHasNoStamp() {
        launchChat(theme: "onelineCat", extra: ["-ui-markdown-reply"])
        sendQuestion()
        XCTAssertTrue(app.staticTexts["chatAssistantText"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(stamp.exists)
        capture("success-no-stamp")
    }

    func testMinimalSkinKeepsTextOnlyFailure() {
        launchChat(theme: "softMinimal", extra: ["-ui-chat-failure"])
        sendQuestion()
        XCTAssertTrue(app.staticTexts["chatAssistantText"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(stamp.exists)
        capture("minimal-error-no-stamp")
    }

    private var stamp: XCUIElement {
        app.descendants(matching: .any)["catErrorStamp"].firstMatch
    }

    private func checkFailure(theme: String, extra: [String] = []) {
        launchChat(theme: theme, extra: ["-ui-chat-failure"] + extra)
        sendQuestion()
        XCTAssertTrue(stamp.waitForExistence(timeout: 10))
        let reply = app.staticTexts["chatAssistantText"].firstMatch
        XCTAssertTrue(reply.label.contains("今はAIを利用できません"))
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "catErrorStamp").count, 1)
        XCTAssertTrue(stamp.label.contains("だめだ〜"))
        XCTAssertFalse(app.staticTexts["chatAssistantStreaming"].exists)

        // Wait for scroll-to-bottom to settle before checking real layout space.
        let inside = NSPredicate { _, _ in
            let frame = self.stamp.frame
            let input = self.app.descendants(matching: .any)["miraChatInput"].firstMatch.frame
            return frame.minX >= 24 && frame.maxX <= self.app.frame.maxX - 24
                && frame.maxY <= input.minY - 8 && frame.minY >= 100
        }
        expectation(for: inside, evaluatedWith: nil)
        waitForExpectations(timeout: 8)
        XCTAssertEqual(stamp.frame.minX, reply.frame.minX, accuracy: 1,
                       "The stamp must share Mira's leading edge, including at large text sizes")
        capture("\(theme)-failure\(extra.isEmpty ? "" : "-large-text")")

        // Reset is a real dismissal path: the error must not leak into a new chat.
        app.buttons["新しい会話"].tap()
        XCTAssertFalse(stamp.exists)
    }

    private func launchChat(theme: String, extra: [String]) {
        app.launchArguments = ["-ui-testing", "-reset-demo", "-ui-theme", theme,
                               "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"] + extra
        app.launch()
        let recommended = app.buttons["おすすめを確認"]
        if recommended.waitForExistence(timeout: 5) {
            recommended.tap()
            let start = app.buttons["余白を置いて始める"]
            XCTAssertTrue(start.waitForExistence(timeout: 5))
            start.tap()
        }
        let companion = app.buttons["miraCompanionButton"]
        XCTAssertTrue(companion.waitForExistence(timeout: 12))
        companion.tap()
        XCTAssertTrue(app.descendants(matching: .any)["miraChatInput"].waitForExistence(timeout: 5))
        XCTAssertFalse(stamp.exists, "Welcome and proactive suggestions are not failures")
    }

    private func sendQuestion() {
        // The chat can open below the welcome suggestions. Use the always-reachable
        // composer and also verify the error fits above it with the keyboard up.
        let input = app.descendants(matching: .any)["miraChatInput"].firstMatch
        input.tap()
        input.typeText("今月ちゃんと休めてる？")
        app.buttons["miraChatSend"].tap()
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
