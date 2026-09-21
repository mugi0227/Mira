import XCTest

final class MiraScreenshotUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCaptureRepresentativeScreens() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing", "-reset-demo"]
        app.launch()

        try ensureOnboarding(in: app)
        try capture("01-onboarding-welcome")

        app.buttons["自分に合わせて設定する"].tap()
        for _ in 0..<2 {
            tapNext(in: app)
        }

        XCTAssertTrue(app.staticTexts["普段、予定を入れたくない時間はある？"].waitForExistence(timeout: 4))
        try capture("02-onboarding-base-hours")

        tapNext(in: app)
        tapNext(in: app)
        try capture("03-onboarding-ready")

        let start = app.buttons["余白を置いて始める"]
        XCTAssertTrue(start.waitForExistence(timeout: 4))
        start.tap()
        XCTAssertTrue(app.buttons["ホーム"].waitForExistence(timeout: 8))
        settle(1.0)
        try capture("04-home-full-width-calendar")
        try capture("05-home-universal-assistant")

        try captureEventEntrySecretary(in: app)
        try captureContextPicker(in: app)
        try captureConversationalScheduling(in: app)
        try captureDeclineGenerator(in: app)
        try captureNaturalLanguageChangePreview(in: app)
        try captureNaturalEventPreview(in: app)

        app.buttons["調整"].tap()
        settle()
        try capture("13-adjustments-soft-holds")

        app.buttons["マイ余白"].tap()
        settle()
        try capture("14-my-margins-automatic-plan")

        let rebalanceButton = app.buttons["完成した組み直し案を見る"]
        if rebalanceButton.waitForExistence(timeout: 2) {
            rebalanceButton.tap()
            XCTAssertTrue(app.navigationBars["余白の再設計"].waitForExistence(timeout: 4))
            settle()
            try capture("15-rebalance-complete-proposal")
            app.navigationBars["余白の再設計"].buttons["閉じる"].tap()
            settle()
        }

        let baseHours = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "普段は予定を置かない時間")).firstMatch
        if baseHours.waitForExistence(timeout: 3) {
            baseHours.tap()
            XCTAssertTrue(app.navigationBars["基本時間"].waitForExistence(timeout: 4))
            settle()
            try capture("16-base-hours-editor")
            app.buttons["キャンセル"].tap()
            settle()
        }

        app.buttons["設定"].tap()
        settle()
        try capture("17-settings")

        let marginAuto = app.staticTexts["余白のおまかせ"]
        if marginAuto.waitForExistence(timeout: 3) {
            marginAuto.tap()
            XCTAssertTrue(app.navigationBars["余白のおまかせ"].waitForExistence(timeout: 4))
            settle()
            try capture("18-margin-comfort-settings")
            app.navigationBars["余白のおまかせ"].buttons.firstMatch.tap()
            settle()
        }

        let skinText = app.staticTexts["スキン"]
        if skinText.waitForExistence(timeout: 3) {
            skinText.tap()
            XCTAssertTrue(app.navigationBars["スキン"].waitForExistence(timeout: 4))
            settle()
            try capture("19-skin-picker")
            app.navigationBars["スキン"].buttons.firstMatch.tap()
            settle()
        }

        let importText = app.staticTexts["古いカレンダーから移行"]
        XCTAssertTrue(importText.waitForExistence(timeout: 4))
        importText.tap()
        XCTAssertTrue(app.navigationBars["カレンダーの引っ越し"].waitForExistence(timeout: 4))
        settle()
        try capture("20-legacy-import-intro")

        let tryImport = app.buttons["移行を試す"]
        XCTAssertTrue(tryImport.waitForExistence(timeout: 3))
        tryImport.tap()
        settle()
        try capture("21-legacy-import-source")

        let analyze = app.buttons["サンプルPDFを読み取る"]
        XCTAssertTrue(analyze.waitForExistence(timeout: 3))
        analyze.tap()
        XCTAssertTrue(app.staticTexts["読み取った予定"].waitForExistence(timeout: 6))
        settle()
        try capture("22-legacy-import-review")
    }

    private func captureEventEntrySecretary(in app: XCUIApplication) throws {
        let addMenu = app.buttons["追加メニュー"]
        XCTAssertTrue(addMenu.waitForExistence(timeout: 4))
        addMenu.tap()

        let addItem = app.buttons["予定・余白を追加"]
        XCTAssertTrue(addItem.waitForExistence(timeout: 3))
        addItem.tap()

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
        settle(0.8)
        try capture("06-event-entry-secretary")

        let addButton = app.navigationBars["予定を追加"].buttons["追加"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        addButton.tap()

        let override = app.buttons["このまま追加する"]
        let finalOverride = app.buttons["今回は例外として追加"]
        XCTAssertTrue(
            override.waitForExistence(timeout: 8) || finalOverride.waitForExistence(timeout: 1),
            "Explicit user override must remain available"
        )
        try capture("07-event-entry-explicit-override")

        let back = app.buttons["いったん戻る"]
        XCTAssertTrue(back.waitForExistence(timeout: 3))
        back.tap()
        app.navigationBars["予定を追加"].buttons["保存して閉じる"].tap()
        XCTAssertTrue(app.buttons["ホーム"].waitForExistence(timeout: 4))
        settle()
    }

    private func captureContextPicker(in app: XCUIApplication) throws {
        let picker = app.buttons["contextPickerButton"]
        XCTAssertTrue(picker.waitForExistence(timeout: 4))
        picker.tap()
        XCTAssertTrue(app.navigationBars["この話について"].waitForExistence(timeout: 4))
        settle()
        try capture("08-context-picker-tabs")
        app.navigationBars["この話について"].buttons["閉じる"].tap()
        settle()
    }

    private func captureConversationalScheduling(in app: XCUIApplication) throws {
        try sendToMira("来月友達と焼肉行きたい", in: app)
        XCTAssertTrue(app.navigationBars["日程を探す"].waitForExistence(timeout: 12))
        settle(1.0)
        try capture("09-conversational-scheduling-recommendations")
        XCTAssertTrue(app.staticTexts["Miraの案を添削するだけ"].exists)
        app.navigationBars["日程を探す"].buttons["保存して閉じる"].tap()
        settle()
    }

    private func captureDeclineGenerator(in app: XCUIApplication) throws {
        try sendToMira("この誘い断りたい", in: app)
        XCTAssertTrue(app.staticTexts["嘘をつかずに、やわらかく断るにゃ"].waitForExistence(timeout: 12))
        settle()
        try capture("10-decline-message-gacha")
        let close = app.navigationBars.buttons["閉じる"].firstMatch
        XCTAssertTrue(close.exists)
        close.tap()
        settle()
    }

    private func captureNaturalLanguageChangePreview(in app: XCUIApplication) throws {
        let picker = app.buttons["contextPickerButton"]
        picker.tap()
        XCTAssertTrue(app.navigationBars["この話について"].waitForExistence(timeout: 4))
        let confirmed = app.segmentedControls.buttons["確定予定"]
        XCTAssertTrue(confirmed.waitForExistence(timeout: 3))
        confirmed.tap()
        let target = app.staticTexts["会社の飲み会"]
        XCTAssertTrue(target.waitForExistence(timeout: 4))
        target.tap()
        XCTAssertTrue(app.otherElements["pinnedContextChip"].waitForExistence(timeout: 4))

        try sendToMira("19時からになった", in: app)
        XCTAssertTrue(app.navigationBars["変更プレビュー"].waitForExistence(timeout: 12))
        settle()
        try capture("11-natural-language-change-preview")
        app.navigationBars["変更プレビュー"].buttons["キャンセル"].tap()
        settle()
        let unpin = app.buttons["案件指定を外す"]
        if unpin.exists { unpin.tap() }
    }

    private func captureNaturalEventPreview(in app: XCUIApplication) throws {
        try sendToMira("10月15日19時にカフェを予定に追加", in: app)
        XCTAssertTrue(app.navigationBars["予定の確認"].waitForExistence(timeout: 12))
        settle()
        try capture("12-natural-language-event-preview")
        app.navigationBars["予定の確認"].buttons["キャンセル"].tap()
        settle()
    }

    private func sendToMira(_ text: String, in app: XCUIApplication) throws {
        let input = app.descendants(matching: .any)["miraQuickInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText(text)
        let send = app.buttons["miraSendButton"]
        XCTAssertTrue(send.waitForExistence(timeout: 3))
        send.tap()
    }

    private func tapNext(in app: XCUIApplication) {
        let next = app.buttons["次へ"]
        XCTAssertTrue(next.waitForExistence(timeout: 4))
        next.tap()
        settle()
    }

    private func ensureOnboarding(in app: XCUIApplication) throws {
        if app.buttons["おすすめを確認"].waitForExistence(timeout: 4) {
            return
        }

        XCTAssertTrue(app.buttons["設定"].waitForExistence(timeout: 6))
        app.buttons["設定"].tap()

        let reset = app.buttons["サンプル状態へリセット"]
        XCTAssertTrue(reset.waitForExistence(timeout: 4))
        reset.tap()

        let confirm = app.buttons["リセット"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 4))
        confirm.tap()

        XCTAssertTrue(app.buttons["おすすめを確認"].waitForExistence(timeout: 6))
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
