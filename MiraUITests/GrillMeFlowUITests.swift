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
        let input = app.textFields["Miraに雑に投げる…"]
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

    func testPastedEventShowsHumanReviewedPreview() throws {
        let input = app.textFields["Miraに雑に投げる…"]
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

        for _ in 0..<5 {
            let next = app.buttons["次へ"]
            if next.waitForExistence(timeout: 3) {
                next.tap()
            }
        }
        let finish = app.buttons["余白を置いて始める"]
        if finish.waitForExistence(timeout: 4) {
            finish.tap()
        }
        _ = app.textFields["Miraに雑に投げる…"].waitForExistence(timeout: 12)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
