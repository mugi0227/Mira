import XCTest

final class WorkDayUITests: XCTestCase {
    func testWorkDayMarksBandsToggleAndExplanation() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-demo", "-ui-theme", "softMinimal",
                               "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        if app.buttons["おすすめを確認"].waitForExistence(timeout: 5) {
            app.buttons["おすすめを確認"].tap()
            XCTAssertTrue(app.buttons["余白を置いて始める"].waitForExistence(timeout: 5))
            app.buttons["余白を置いて始める"].tap()
        }
        func element(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }
        XCTAssertTrue(element("monthCalendar").waitForExistence(timeout: 12))
        let weekday = app.buttons["calendar-date-2026-09-01"]
        XCTAssertTrue(weekday.label.contains("仕事の日"))
        XCTAssertTrue(element("workDayMark-2026-09-01").exists)
        XCTAssertFalse(element("workDayMark-2026-09-06").exists)
        XCTAssertFalse(app.buttons["calendar-date-2026-09-06"].label.contains("仕事の日"))
        for day in ["01", "10", "17", "24"] {
            let ring = element("whitespace-2026-09-\(day)").frame
            let mark = element("workDayMark-2026-09-\(day)").frame
            let dx = max(mark.minX - ring.midX, ring.midX - mark.maxX, 0)
            let dy = max(mark.minY - ring.midY, ring.midY - mark.maxY, 0)
            XCTAssertGreaterThanOrEqual(hypot(dx, dy) - ring.width / 2, 3, "Work mark must clear the ring on September \(day)")
        }
        capture("work-day-month", app: app)

        weekday.tap()
        let toggle = app.buttons["workDayToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "オン")
        let band = element("workDayBand")
        XCTAssertTrue(band.waitForExistence(timeout: 5))
        XCTAssertTrue(band.label.contains("9:00–18:00"))
        XCTAssertTrue(band.isHittable)
        let firstHour = app.staticTexts["09:00"]
        XCTAssertTrue(firstHour.isHittable)
        XCTAssertGreaterThanOrEqual(firstHour.frame.minY, toggle.frame.maxY + 8)
        capture("work-day-on", app: app)

        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "オフ")
        XCTAssertFalse(band.exists)
        capture("work-day-off", app: app)

        app.buttons["workDayInfoButton"].tap()
        let explanation = element("workDayExplanation")
        XCTAssertTrue(explanation.waitForExistence(timeout: 5))
        XCTAssertTrue(explanation.label.contains("9:00–18:00"))
        XCTAssertTrue(explanation.label.contains("祝日の扱いは設定で変更"))
        capture("work-day-explanation", app: app)
        app.buttons["閉じる"].tap()
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(element("monthCalendar").waitForExistence(timeout: 5))
        XCTAssertFalse(element("workDayMark-2026-09-01").exists)
        XCTAssertFalse(weekday.label.contains("仕事の日"))
        XCTAssertTrue(element("whitespace-2026-09-01").label.contains("16時間"))
        capture("work-day-month-off", app: app)

        app.buttons["設定"].firstMatch.tap()
        let holidayToggle = app.switches["祝日を仕事の日から除く"]
        for _ in 0..<6 where !holidayToggle.isHittable { app.swipeUp() }
        XCTAssertTrue(holidayToggle.isHittable)
        capture("work-day-settings", app: app)
    }

    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
