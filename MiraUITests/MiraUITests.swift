import XCTest

final class MiraUITests: XCTestCase {
    func testOnboardingReachesHome() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing", "-reset-demo"]
        app.launch()

        let next = app.buttons["おすすめを確認"]
        if next.waitForExistence(timeout: 4) {
            next.tap()
            let start = app.buttons["余白を置いて始める"]
            XCTAssertTrue(start.waitForExistence(timeout: 3))
            start.tap()
        }

        XCTAssertTrue(app.descendants(matching: .any)["miraQuickInput"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["調整"].exists)
        XCTAssertTrue(app.buttons["マイ余白"].exists)
    }
}
