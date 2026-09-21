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

    func testUniversalInputOpensPreselectedSchedulingMode() throws {
        let input = app.descendants(matching: .any)["miraQuickInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 12))
        input.tap()
        input.typeText("来月友達と焼肉行きたい")
        app.buttons["Miraへ送る"].tap()

        if app.staticTexts["どのくらいの予定になりそう？"].waitForExistence(timeout: 4) {
            app.buttons["1〜2時間"].tap()
        }

        XCTAssertTrue(app.navigationBars["日程を探す"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Miraの案を添削するだけ"].exists)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'おすすめ' OR value CONTAINS '選択済み'")).count > 0)
        capture("01-grill-scheduling-mode")

        let clear = app.buttons["おすすめをすべて外す"]
        if clear.exists { clear.tap() }
        capture("02-grill-recommendations-cleared")
    }

    func testManualContextPickerHasCategoryTabsAndPastOptIn() throws {
        let contextButton = app.buttons["この話について予定を指定"]
        XCTAssertTrue(contextButton.waitForExistence(timeout: 10))
        contextButton.tap()

        XCTAssertTrue(app.navigationBars["この話について"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["進行中"].exists)
        XCTAssertTrue(app.buttons["検討中"].exists)
        XCTAssertTrue(app.buttons["確定予定"].exists)
        XCTAssertTrue(app.switches["過去も検索"].exists)
        capture("03-grill-context-picker")
    }

    func testCatSkinKeepsNavigationAndSheetsUsable() throws {
        let home = app.buttons["miraTab-home"]
        XCTAssertTrue(home.waitForExistence(timeout: 10))
        XCTAssertTrue(home.isHittable)
        XCTAssertTrue(app.descendants(matching: .any)["miraQuickInput"].exists)
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

        let contextPicker = app.buttons["contextPickerButton"]
        XCTAssertTrue(contextPicker.waitForExistence(timeout: 4))
        contextPicker.tap()
        let contextSheet = app.navigationBars["この話について"]
        XCTAssertTrue(contextSheet.waitForExistence(timeout: 4))
        XCTAssertTrue(app.segmentedControls.buttons["進行中"].exists)
        XCTAssertTrue(app.switches["includePastToggle"].exists)
        capture("cat-skin-context-sheet")
        contextSheet.buttons["閉じる"].tap()
        XCTAssertTrue(home.waitForExistence(timeout: 4))
        XCTAssertTrue(home.isHittable)
    }

    func testPastedEventShowsHumanReviewedPreview() throws {
        let input = app.descendants(matching: .any)["miraQuickInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.tap()
        input.typeText("9/12 カフェを予定に追加して")
        app.buttons["Miraへ送る"].tap()

        if app.staticTexts["どのくらいの予定になりそう？"].waitForExistence(timeout: 4) {
            app.buttons["1〜2時間"].tap()
        }

        let preview = app.navigationBars["予定の確認"]
        if preview.waitForExistence(timeout: 15) {
            XCTAssertTrue(app.staticTexts["決めるのはあなた。影響と別案を先に見るにゃ。"].exists)
            capture("04-grill-event-preview")
        } else {
            XCTAssertTrue(app.navigationBars["日程を探す"].exists)
            capture("04-grill-event-scheduling-fallback")
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
        _ = app.descendants(matching: .any)["miraQuickInput"].waitForExistence(timeout: 12)
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
