import XCTest

final class MiraStyleUITests: XCTestCase {
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
        title.tap()
        title.typeText("友だちの出張メモ")
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
        app.navigationBars["予定を追加"].buttons["追加"].tap()
        XCTAssertTrue(menu.waitForExistence(timeout: 8))
        let memo = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "友だちの出張メモ")).firstMatch
        XCTAssertTrue(memo.waitForExistence(timeout: 5))
        let calendar = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        calendar.name = "memo-calendar"
        calendar.lifetime = .keepAlways
        add(calendar)
    }

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-demo", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
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
