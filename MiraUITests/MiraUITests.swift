import XCTest

final class MiraUITests: XCTestCase {
    func testOnboardingReachesHome() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing"]
        app.launch()

        let next = app.buttons["次へ"]
        if next.waitForExistence(timeout: 4) {
            for _ in 0..<5 {
                XCTAssertTrue(next.waitForExistence(timeout: 3))
                next.tap()
            }
            let start = app.buttons["余白を置いて始める"]
            XCTAssertTrue(start.waitForExistence(timeout: 3))
            start.tap()
        }

        XCTAssertTrue(app.navigationBars["余白"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.tabBars.buttons["調整"].exists)
        XCTAssertTrue(app.tabBars.buttons["マイ余白"].exists)
    }
}
