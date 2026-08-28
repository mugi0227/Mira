import XCTest

final class MiraScreenshotUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCaptureRepresentativeScreens() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing"]
        app.launch()

        try ensureOnboarding(in: app)
        try capture("01-onboarding-welcome")

        for _ in 0..<4 {
            tapNext(in: app)
        }

        XCTAssertTrue(app.staticTexts["普段、予定を入れたくない時間はある？"].waitForExistence(timeout: 4))
        try capture("02-onboarding-base-hours")

        tapNext(in: app)
        try capture("03-onboarding-ready")

        let start = app.buttons["余白を置いて始める"]
        XCTAssertTrue(start.waitForExistence(timeout: 4))
        start.tap()
        XCTAssertTrue(app.tabBars.buttons["ホーム"].waitForExistence(timeout: 8))
        settle(1.0)
        try capture("04-home-full-width-calendar")

        try captureEventEntrySecretary(in: app)

        app.tabBars.buttons["調整"].tap()
        settle()
        try capture("07-adjustments")

        app.tabBars.buttons["マイ余白"].tap()
        settle()
        try capture("08-my-margins")

        let baseHours = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "普段は予定を置かない時間")).firstMatch
        if baseHours.waitForExistence(timeout: 3) {
            baseHours.tap()
            XCTAssertTrue(app.navigationBars["基本時間"].waitForExistence(timeout: 4))
            settle()
            try capture("09-base-hours-editor")
            app.buttons["キャンセル"].tap()
            settle()
        }

        app.tabBars.buttons["設定"].tap()
        settle()
        try capture("10-settings")

        let skinText = app.staticTexts["スキン"]
        if skinText.waitForExistence(timeout: 3) {
            skinText.tap()
            XCTAssertTrue(app.navigationBars["スキン"].waitForExistence(timeout: 4))
            settle()
            try capture("11-skin-picker")
            app.navigationBars["スキン"].buttons.firstMatch.tap()
            settle()
        }

        let importText = app.staticTexts["古いカレンダーから移行"]
        XCTAssertTrue(importText.waitForExistence(timeout: 4))
        importText.tap()
        XCTAssertTrue(app.navigationBars["カレンダーの引っ越し"].waitForExistence(timeout: 4))
        settle()
        try capture("12-legacy-import-intro")

        let tryImport = app.buttons["移行を試す"]
        XCTAssertTrue(tryImport.waitForExistence(timeout: 3))
        tryImport.tap()
        settle()
        try capture("13-legacy-import-source")

        let analyze = app.buttons["サンプルPDFを読み取る"]
        XCTAssertTrue(analyze.waitForExistence(timeout: 3))
        analyze.tap()
        XCTAssertTrue(app.staticTexts["読み取った予定"].waitForExistence(timeout: 6))
        settle()
        try capture("14-legacy-import-review")
    }

    private func captureEventEntrySecretary(in app: XCUIApplication) throws {
        let add = app.buttons["予定または余白を追加"]
        XCTAssertTrue(add.waitForExistence(timeout: 4))
        add.tap()

        XCTAssertTrue(app.navigationBars["予定を追加"].waitForExistence(timeout: 4))
        let titleField = app.textFields["例：友達とご飯"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 4))
        titleField.tap()
        titleField.typeText("カフェに行く\n")
        settle(0.5)

        let secretaryHeader = app.staticTexts["Miraの秘書チェック"]
        for _ in 0..<3 where !secretaryHeader.isHittable {
            app.swipeUp()
            settle(0.25)
        }
        XCTAssertTrue(secretaryHeader.waitForExistence(timeout: 4))

        let guidance = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "にゃ")
        ).allElementsBoundByIndex
        XCTAssertTrue(
            guidance.contains(where: { $0.label.contains("余白") || $0.label.contains("目標") || $0.label.contains("基本時間") || $0.label.contains("大丈夫") }),
            "Secretary guidance should be visible after event input"
        )
        settle(0.8)
        try capture("05-event-entry-secretary")

        let addButton = app.navigationBars["予定を追加"].buttons["追加"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        addButton.tap()

        let override = app.buttons["このまま追加する"]
        let finalOverride = app.buttons["今回は例外として追加"]
        XCTAssertTrue(
            override.waitForExistence(timeout: 8) || finalOverride.waitForExistence(timeout: 1),
            "Explicit user override must remain available"
        )
        try capture("06-event-entry-explicit-override")

        let back = app.buttons["いったん戻る"]
        XCTAssertTrue(back.waitForExistence(timeout: 3))
        back.tap()
        app.navigationBars["予定を追加"].buttons["閉じる"].tap()
        XCTAssertTrue(app.tabBars.buttons["ホーム"].waitForExistence(timeout: 4))
        settle()
    }

    private func tapNext(in app: XCUIApplication) {
        let next = app.buttons["次へ"]
        XCTAssertTrue(next.waitForExistence(timeout: 4))
        next.tap()
        settle()
    }

    private func ensureOnboarding(in app: XCUIApplication) throws {
        if app.buttons["次へ"].waitForExistence(timeout: 4) {
            return
        }

        XCTAssertTrue(app.tabBars.buttons["設定"].waitForExistence(timeout: 6))
        app.tabBars.buttons["設定"].tap()

        let reset = app.buttons["サンプル状態へリセット"]
        XCTAssertTrue(reset.waitForExistence(timeout: 4))
        reset.tap()

        let confirm = app.buttons["リセット"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 4))
        confirm.tap()

        XCTAssertTrue(app.buttons["次へ"].waitForExistence(timeout: 6))
        settle()
    }

    private func capture(_ name: String) throws {
        settle(0.35)
        let screenshot = XCUIScreen.main.screenshot()

        let directory = URL(fileURLWithPath: "/tmp/mira-screenshots", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(name).png")
        try screenshot.pngRepresentation.write(to: url, options: .atomic)

        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func settle(_ seconds: TimeInterval = 0.6) {
        Thread.sleep(forTimeInterval: seconds)
    }
}
