import XCTest

final class HomeWhitespaceUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testDailyMetersNavigateWithMonthAndKeepDayNavigation() {
        launchHome(theme: "silhouetteCat")
        let first = element("whitespace-2026-09-01")
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertTrue(first.label.contains("7時間"))
        XCTAssertTrue(element("whitespace-2026-09-06").label.contains("16時間"))
        app.buttons["次の月"].tap()
        XCTAssertTrue(element("whitespace-2026-10-01").waitForExistence(timeout: 5))
        app.buttons["前の月"].tap()
        let day = element("calendar-day-2026-09-06")
        XCTAssertTrue(day.waitForExistence(timeout: 5))
        day.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
        XCTAssertTrue(app.navigationBars.matching(NSPredicate(format: "identifier CONTAINS %@", "9月6日")).firstMatch.waitForExistence(timeout: 5))
        capture("whitespace-day-navigation")
    }

    func testNonOccupyingEventUpdatesRingAndPersistsAcrossLaunch() {
        launchHome(theme: "onelineCat")
        let ring = element("whitespace-2026-09-05")
        XCTAssertTrue(ring.waitForExistence(timeout: 5))
        XCTAssertTrue(ring.label.contains("12時間"))
        let dinner = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "みんなでご飯、")).firstMatch
        XCTAssertTrue(dinner.waitForExistence(timeout: 5))
        dinner.tap()
        let toggle = app.buttons["eventOccupiesTime"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()
        app.buttons["閉じる"].tap()
        XCTAssertTrue(ring.label.contains("16時間"))
        app.terminate()
        app.launchArguments.removeAll { $0 == "-reset-demo" }
        app.launch()
        XCTAssertTrue(element("whitespace-2026-09-05").waitForExistence(timeout: 10))
        XCTAssertTrue(element("whitespace-2026-09-05").label.contains("16時間"))
        capture("whitespace-memo-persisted")
    }

    func testSummaryExplainsMeaningAndFriendViewHidesPersonalMeters() {
        launchHome(theme: "pixelCat")
        let summary = app.buttons["monthWhitespaceSummary"]
        for _ in 0..<3 where !summary.isHittable { app.swipeUp() }
        XCTAssertTrue(summary.isHittable)
        summary.tap()
        XCTAssertTrue(app.navigationBars["余白メーターについて"].waitForExistence(timeout: 5))
        capture("whitespace-explanation")
        app.buttons["閉じる"].tap()
        app.swipeDown()
        app.swipeDown()
        app.buttons["friendViewToggle"].tap()
        XCTAssertFalse(element("whitespace-2026-09-01").exists)
        XCTAssertFalse(app.buttons["monthWhitespaceSummary"].exists)
        capture("whitespace-friend-privacy")
    }

    private func launchHome(theme: String) {
        app.launchArguments = ["-ui-testing", "-reset-demo", "-ui-theme", theme,
                               "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        let recommended = app.buttons["おすすめを確認"]
        if recommended.waitForExistence(timeout: 5) {
            recommended.tap()
            let start = app.buttons["余白を置いて始める"]
            XCTAssertTrue(start.waitForExistence(timeout: 5))
            start.tap()
        }
        XCTAssertTrue(element("monthCalendar").waitForExistence(timeout: 12))
        // The onboarding success toast otherwise temporarily covers the header.
        Thread.sleep(forTimeInterval: 3)
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
