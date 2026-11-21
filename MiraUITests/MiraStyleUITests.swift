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
        XCTAssertGreaterThanOrEqual(monday.frame.minX - calendar.frame.minX, 8)
        XCTAssertGreaterThanOrEqual(calendar.frame.maxX - sunday.frame.maxX, 8)
        XCTAssertGreaterThanOrEqual(monday.frame.minY - calendar.frame.minY, 44)
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
        let dayHeader = day.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
            .withOffset(CGVector(dx: 0, dy: 15))
        dayHeader.tap()
        XCTAssertTrue(app.buttons["この日に予定を追加"].waitForExistence(timeout: 5))
        capture("rounded-day")
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
        let colors = app.descendants(matching: .any)["appColorSettings"].firstMatch
        for _ in 0..<4 where !colors.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(colors.waitForExistence(timeout: 5))
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
