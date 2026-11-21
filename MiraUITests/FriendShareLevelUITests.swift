import XCTest

final class FriendShareLevelUITests: XCTestCase {
    func testRecipientLevelUpdatesGrid() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-reset-demo", "-friend-share-test", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        if app.staticTexts["自分のための時間を守ろう。"].waitForExistence(timeout: 5) {
            app.buttons["おすすめを確認"].tap()
            let finish = app.buttons["余白を置いて始める"]
            XCTAssertTrue(finish.waitForExistence(timeout: 5))
            finish.tap()
        }
        let toggle = app.buttons["friendViewToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 15))
        toggle.tap()
        let recipientPicker = app.buttons["friendRecipientPicker"]
        XCTAssertTrue(recipientPicker.waitForExistence(timeout: 5))
        recipientPicker.tap()
        let recipient = app.buttons["はる"]
        if !recipient.waitForExistence(timeout: 3) { recipientPicker.tap() }
        XCTAssertTrue(recipient.waitForExistence(timeout: 5))
        recipient.tap()
        app.buttons["friendLevelPicker"].tap()
        attach("friend-level-picker")
        app.buttons["埋まりだけ"].tap()
        let content = app.staticTexts.matching(identifier: "friendDayContent")
        XCTAssertTrue(content.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(content.allElementsBoundByIndex.contains { $0.label.contains("予定あり") && $0.label.contains(":") })
        XCTAssertTrue(app.buttons["friendShareText"].exists)
        attach("friend-share-card")
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
