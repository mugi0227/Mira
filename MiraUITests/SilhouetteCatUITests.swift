import XCTest

final class SilhouetteCatUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-demo", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
    }

    func testSelectSilhouetteSkin() {
        app.launch()
        finishOnboarding()
        openThemePicker()
        let card = app.buttons["theme-silhouetteCat"]
        for _ in 0..<3 where !card.isHittable { app.swipeUp() }
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["miraTab-home"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["silhouetteCat"].firstMatch.waitForExistence(timeout: 5))
    }

    func testCaptureSilhouetteScreens() {
        app.launchArguments += ["-ui-theme", "silhouetteCat"]
        app.launch()
        if app.buttons["おすすめを確認"].waitForExistence(timeout: 5) {
            capture("silhouette-onboarding-welcome")
        }
        finishOnboarding()
        capture("silhouette-home")
        app.buttons["miraChatButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["miraChatInput"].waitForExistence(timeout: 5))
        capture("silhouette-chat")
        app.buttons["閉じる"].tap()
        for tab in ["margins", "adjustments"] {
            app.buttons["miraTab-\(tab)"].tap()
            capture("silhouette-\(tab)")
        }
        openThemePicker()
        let card = app.buttons["theme-silhouetteCat"]
        for _ in 0..<3 where !card.isHittable { app.swipeUp() }
        XCTAssertTrue(card.isHittable)
        capture("silhouette-theme-picker")
    }

    private func finishOnboarding() {
        let recommended = app.buttons["おすすめを確認"]
        if recommended.waitForExistence(timeout: 5) {
            recommended.tap()
            let start = app.buttons["余白を置いて始める"]
            XCTAssertTrue(start.waitForExistence(timeout: 5))
            start.tap()
        }
        XCTAssertTrue(app.buttons["miraChatButton"].waitForExistence(timeout: 12))
    }

    private func openThemePicker() {
        app.buttons["miraTab-settings"].tap()
        let row = app.buttons.containing(.staticText, identifier: "スキン").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.navigationBars["スキン"].waitForExistence(timeout: 5))
    }

    private func capture(_ name: String) {
        Thread.sleep(forTimeInterval: 0.6)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
