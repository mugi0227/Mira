import XCTest

final class EventRoomCalendarUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing", "-reset-demo",
            "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"
        ]
    }

    func testCalendarLightsOnlyDaysWithOneSlotLongEnough() {
        openEventForm()
        let calendar = element("eventRoomCalendar")
        XCTAssertTrue(calendar.waitForExistence(timeout: 5))
        reveal(calendar)
        capture("event-room-two-hours")

        // Default 18:00–20:00 fits a workday's 18–23 evening; 8/31 is past.
        XCTAssertEqual(day("2026-09-02").value as? String, "空きあり")
        XCTAssertEqual(day("2026-09-06").value as? String, "空きあり")
        XCTAssertNotEqual(day("2026-08-31").value as? String, "空きあり")

        setHour("12", picker: "eventStartTime")
        // 8h: a workday only has 7–9 and 18–23 left, so only free weekends light up.
        XCTAssertTrue(waitForValue(day("2026-09-02"), notEqual: "空きあり"))
        XCTAssertEqual(day("2026-09-06").value as? String, "空きあり")
        XCTAssertEqual(day("2026-09-12").value as? String, "空きあり")
        reveal(calendar)
        capture("event-room-eight-hours")

        day("2026-09-06").tap()
        XCTAssertTrue(element("eventSelectedDate").label.contains("9月6日"))

        scrollToTop()
        let allDay = app.switches["終日"].firstMatch
        XCTAssertTrue(allDay.waitForExistence(timeout: 5))
        // A Form toggle only flips when the switch itself, at the row's trailing edge, is tapped.
        allDay.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        reveal(calendar)
        XCTAssertTrue(waitForValue(day("2026-09-06"), notEqual: "空きあり"))
        XCTAssertTrue(element("eventRoomLegend").label.contains("終日"))
        capture("event-room-all-day")
    }

    private func openEventForm() {
        app.launch()
        let recommended = app.buttons["おすすめを確認"]
        if recommended.waitForExistence(timeout: 5) {
            recommended.tap()
            let start = app.buttons["余白を置いて始める"]
            XCTAssertTrue(start.waitForExistence(timeout: 5))
            start.tap()
        }
        let addMenu = app.buttons["追加メニュー"]
        XCTAssertTrue(addMenu.waitForExistence(timeout: 12))
        addMenu.tap()
        let addItem = app.buttons["予定・余白を追加"]
        if !addItem.waitForExistence(timeout: 3) {
            addMenu.tap()
        }
        XCTAssertTrue(addItem.waitForExistence(timeout: 3))
        addItem.tap()
        XCTAssertTrue(app.navigationBars["予定を追加"].waitForExistence(timeout: 5))
    }

    private func scrollToTop() {
        let title = app.textFields["例：友達とご飯"]
        var attempts = 0
        while !title.isHittable, attempts < 4 {
            app.swipeDown()
            attempts += 1
        }
    }

    private func setHour(_ hour: String, picker: String) {
        scrollToTop()
        let end = app.datePickers[picker].firstMatch
        XCTAssertTrue(end.waitForExistence(timeout: 5))
        end.tap()
        let wheel = app.pickerWheels.element(boundBy: 0)
        XCTAssertTrue(wheel.waitForExistence(timeout: 5))
        wheel.adjust(toPickerWheelValue: hour)
        app.navigationBars["予定を追加"].tap()
    }

    private func waitForValue(_ element: XCUIElement, notEqual value: String) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value != %@", value), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: 5) == .completed
    }

    private func reveal(_ element: XCUIElement) {
        var attempts = 0
        while !day("2026-09-30").isHittable, attempts < 4 {
            app.swipeUp()
            attempts += 1
        }
    }

    private func day(_ id: String) -> XCUIElement {
        element("room-day-\(id)")
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
