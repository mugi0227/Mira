import XCTest

final class FriendShareLevelUITests: XCTestCase {
    func testBusyOnlyCalendarOpensRedactedDayOnTap() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-reset-demo", "-ui-theme", "softMinimal", "-friend-share-test", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
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
        app.buttons["埋まりだけ"].tap()

        let panel = app.otherElements["friendBusyDayPanel"]
        let busyBlock = app.staticTexts.matching(identifier: "friendDayContent")
            .matching(NSPredicate(format: "label == %@", "17:30–22:45")).firstMatch
        XCTAssertTrue(busyBlock.waitForExistence(timeout: 5))
        XCTAssertFalse(panel.exists)
        attach("busy-only-before-tap")
        busyBlock.tap()

        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertTrue(panel.staticTexts["17:30–22:45 予定あり"].exists)
        XCTAssertFalse(app.staticTexts["みんなでご飯"].exists)
        XCTAssertFalse(app.buttons["inlineDayAdd"].exists)
        XCTAssertFalse(app.buttons["inlineDayTimeBar"].exists)
        attach("busy-only-after-tap")
        busyBlock.tap()
        XCTAssertTrue(panel.waitForNonExistence(timeout: 5))

        let allDayDate = app.buttons["calendar-date-2026-09-07"]
        XCTAssertTrue(allDayDate.exists)
        allDayDate.tap()
        XCTAssertTrue(panel.staticTexts["終日 予定あり"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["美容院"].exists)

        toggle.tap()
        XCTAssertTrue(panel.waitForNonExistence(timeout: 5))
    }

    func testRecipientLevelUpdatesGrid() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-reset-demo", "-ui-theme", "pixelCat", "-friend-share-test", "-friend-share-image-preview", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        for (level, title) in [("busyTimes", "埋まりだけ"), ("titles", "予定名まで")] {
            app.launch()
            if app.staticTexts["自分のための時間を守ろう。"].waitForExistence(timeout: 5) {
                app.buttons["おすすめを確認"].tap()
                let finish = app.buttons["余白を置いて始める"]
                XCTAssertTrue(finish.waitForExistence(timeout: 5))
                finish.tap()
            }
            let toggle = app.buttons["friendViewToggle"]
            XCTAssertTrue(toggle.waitForExistence(timeout: 15))
            assertMonthControls(app)
            attach("demo-\(level)-normal-month-header")
            toggle.tap()
            assertMonthControls(app)
            let recipientPicker = app.buttons["friendRecipientPicker"]
            XCTAssertTrue(recipientPicker.waitForExistence(timeout: 5))
            recipientPicker.tap()
            let recipient = app.buttons["はる"]
            if !recipient.waitForExistence(timeout: 3) { recipientPicker.tap() }
            XCTAssertTrue(recipient.waitForExistence(timeout: 5))
            recipient.tap()
            app.buttons["friendLevelPicker"].tap()
            attach("demo-\(level)-picker")
            app.buttons[title].tap()
            let content = app.staticTexts.matching(identifier: "friendDayContent")
            XCTAssertTrue(content.firstMatch.waitForExistence(timeout: 5))
            if level == "busyTimes" {
                XCTAssertTrue(content.allElementsBoundByIndex.contains { $0.label.contains("–") })
                XCTAssertFalse(content.allElementsBoundByIndex.contains { $0.label.contains("予定あり") })
            }
            XCTAssertTrue(app.staticTexts["見せる相手"].exists)
            XCTAssertTrue(app.staticTexts["見せる範囲"].exists)
            XCTAssertTrue(app.buttons["friendShareText"].exists)
            captureShare(app, level: level)
            app.terminate()
        }
    }

    private func assertMonthControls(_ app: XCUIApplication) {
        let previous = app.buttons["前の月"].frame
        let next = app.buttons["次の月"].frame
        let add = app.buttons["追加メニュー"].frame
        XCTAssertEqual(previous.width, next.width, accuracy: 1)
        XCTAssertEqual(previous.height, next.height, accuracy: 1)
        XCTAssertEqual(previous.midY, next.midY, accuracy: 1)
        XCTAssertGreaterThanOrEqual(next.minX - previous.maxX, 7)
        XCTAssertGreaterThanOrEqual(add.minX - next.maxX, 11)
    }

    private func captureShare(_ app: XCUIApplication, level: String) {
        attach("demo-\(level)-grid")
        app.swipeUp()
        attach("demo-\(level)-grid-scrolled")
        app.swipeDown()
        app.swipeDown()
        let share = app.buttons["friendShareImage"]
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        let preview = app.buttons["friendShareExactImagePreview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        preview.tap()
        XCTAssertTrue(app.images["friendShareExactImage"].waitForExistence(timeout: 5))
        attach("demo-\(level)-exact-shared-image")
        app.buttons["friendShareExactImageClose"].tap()
        share.tap()
        let sheet = app.otherElements["ActivityListView"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))
        attach("demo-\(level)-share-sheet")
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
