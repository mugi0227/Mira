import XCTest

final class MiraCalendarDisplayUITests: XCTestCase {
    func testGeneralSettingsChangeTheMonthCalendar() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-demo", "-ui-theme", "softMinimal", "-AppleInterfaceStyle", "Light"]
        app.launch()
        let recommended = app.buttons["おすすめを確認"]
        if recommended.waitForExistence(timeout: 4) {
            recommended.tap()
            let start = app.buttons["余白を置いて始める"]
            XCTAssertTrue(start.waitForExistence(timeout: 5))
            start.tap()
        }

        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 10))
        tabs.buttons["設定"].tap()
        let link = app.descendants(matching: .any)["calendarDisplaySettings"].firstMatch
        reveal(link, in: app)
        link.tap()
        let general = app.navigationBars["一般設定"]
        XCTAssertTrue(general.waitForExistence(timeout: 5))
        capture("calendar-settings-appearance")
        let startTimeSwitch = app.switches["calendarShowsStartTime"]
        reveal(startTimeSwitch, in: app)
        XCTAssertEqual(startTimeSwitch.value as? String, "1")
        set(startTimeSwitch, on: false)
        app.buttons["カラー文字"].tap()
        set(app.switches["時間予定の区別"], on: true)

        let weekSwitch = app.switches["calendarShowsWeekNumbers"]
        let rokuyoSwitch = app.switches["calendarShowsRokuyo"]
        let holidaySwitch = app.switches["calendarShowsPublicHolidays"]
        reveal(weekSwitch, in: app)
        capture("calendar-settings-list")
        set(weekSwitch, on: true)
        reveal(holidaySwitch, in: app)
        set(holidaySwitch, on: true)
        reveal(rokuyoSwitch, in: app)
        set(rokuyoSwitch, on: true)
        capture("calendar-settings-date-options")
        reveal(app.buttons["重複イベントを削除"], in: app)
        capture("calendar-settings-time")

        tabs.buttons["ホーム"].tap()
        let week = app.staticTexts.matching(identifier: "monthWeekNumber").firstMatch
        let rokuyo = app.staticTexts.matching(identifier: "monthRokuyo").firstMatch
        let publicHoliday = app.staticTexts.matching(identifier: "monthPublicHoliday").matching(NSPredicate(format: "label == %@", "敬老の日")).firstMatch
        XCTAssertTrue(week.waitForExistence(timeout: 5))
        XCTAssertTrue(rokuyo.exists)
        XCTAssertTrue(publicHoliday.exists)
        capture("calendar-month-week-number-rokuyo-and-holiday")

        tabs.buttons["設定"].tap()
        XCTAssertTrue(general.waitForExistence(timeout: 5))
        reveal(rokuyoSwitch, in: app, upwards: false)
        set(rokuyoSwitch, on: false)
        reveal(holidaySwitch, in: app, upwards: false)
        set(holidaySwitch, on: false)
        reveal(weekSwitch, in: app, upwards: false)
        set(weekSwitch, on: false)
        reveal(startTimeSwitch, in: app, upwards: false)
        set(startTimeSwitch, on: true)
        tabs.buttons["ホーム"].tap()
        XCTAssertFalse(week.exists)
        XCTAssertFalse(rokuyo.exists)
        XCTAssertFalse(publicHoliday.exists)
        capture("calendar-month-without-week-number-rokuyo-or-holiday")
    }

    func testResetDemoLaunchRestoresCalendarDisplayDefaults() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-demo", "-ui-theme", "softMinimal"]
        func launchAndOpenGeneralSettings() {
            app.launch()
            let recommended = app.buttons["おすすめを確認"]
            if recommended.waitForExistence(timeout: 4) {
                recommended.tap()
                let start = app.buttons["余白を置いて始める"]
                XCTAssertTrue(start.waitForExistence(timeout: 5))
                start.tap()
            }
            let tabs = app.tabBars.firstMatch
            XCTAssertTrue(tabs.waitForExistence(timeout: 10))
            tabs.buttons["設定"].tap()
            let link = app.descendants(matching: .any)["calendarDisplaySettings"].firstMatch
            reveal(link, in: app)
            link.tap()
            XCTAssertTrue(app.navigationBars["一般設定"].waitForExistence(timeout: 5))
        }

        launchAndOpenGeneralSettings()
        let vertical = app.buttons["縦スクロール（月の見出しを上下に）"]
        let agenda = app.buttons["常に表示"]
        let week = app.switches["calendarShowsWeekNumbers"]
        let rokuyo = app.switches["calendarShowsRokuyo"]
        reveal(vertical, in: app)
        vertical.tap()
        XCTAssertTrue(vertical.isSelected)
        reveal(agenda, in: app)
        agenda.tap()
        XCTAssertTrue(agenda.isSelected)
        reveal(week, in: app)
        set(week, on: true)
        reveal(rokuyo, in: app)
        set(rokuyo, on: true)

        app.terminate()
        launchAndOpenGeneralSettings()
        reveal(vertical, in: app)
        XCTAssertFalse(vertical.isSelected)
        reveal(agenda, in: app)
        XCTAssertFalse(agenda.isSelected)
        reveal(week, in: app)
        XCTAssertEqual(week.value as? String, "0")
        reveal(rokuyo, in: app)
        XCTAssertEqual(rokuyo.value as? String, "0")
    }

    private func set(_ toggle: XCUIElement, on: Bool) {
        if (toggle.value as? String == "1") != on {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        }
        XCTAssertEqual(toggle.value as? String, on ? "1" : "0")
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication, upwards: Bool = true) {
        for _ in 0..<12 {
            var scrollUp = upwards
            if element.exists {
                let above = element.frame.minY < app.navigationBars.firstMatch.frame.maxY + 8
                let below = element.frame.maxY > app.tabBars.firstMatch.frame.minY - 8
                if !above && !below && element.isHittable { return }
                if above || below { scrollUp = below }
            }
            let upper = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.36))
            let lower = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.68))
            if scrollUp { lower.press(forDuration: 0.05, thenDragTo: upper) }
            else { upper.press(forDuration: 0.05, thenDragTo: lower) }
        }
        XCTAssertTrue(element.exists && element.isHittable)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
