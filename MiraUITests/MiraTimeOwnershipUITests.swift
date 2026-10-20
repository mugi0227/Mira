import XCTest

// Loop goals S1/S2/S4/S7 and U1/U2 (docs/loop-goals.md).
final class MiraTimeOwnershipUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-ui-testing"]
        app.launch()
        completeOnboardingIfNeeded()
        let tab = app.tabBars.buttons["Mira"]
        XCTAssertTrue(tab.waitForExistence(timeout: 8))
        tab.tap()
    }

    func testVagueRequestBecomesSuggestionAppliedWithinTwoTapsAndCanBeUndone() {
        let field = app.textFields["mira.request"]
        XCTAssertTrue(field.waitForExistence(timeout: 4))
        field.tap()
        field.typeText("来週は自分の時間を増やしたい")

        // U1: send + apply = two taps after typing.
        app.buttons["送信"].tap()
        let apply = app.buttons["この案で置く"].firstMatch
        XCTAssertTrue(apply.waitForExistence(timeout: 4))
        apply.tap()

        // U2: no confirmation dialog on apply or undo.
        XCTAssertEqual(app.alerts.count, 0)
        let undo = app.buttons["取り消す"].firstMatch
        XCTAssertTrue(scrollTo(undo))
        undo.tap()
        XCTAssertEqual(app.alerts.count, 0)
        XCTAssertTrue(app.staticTexts["取り消しました"].waitForExistence(timeout: 4))
    }

    func testUnknownRequestOffersChoices() {
        let field = app.textFields["mira.request"]
        XCTAssertTrue(field.waitForExistence(timeout: 4))
        field.tap()
        field.typeText("ラーメン")
        app.buttons["送信"].tap()
        let choice = app.buttons["来週の自分の時間を増やす"]
        XCTAssertTrue(choice.waitForExistence(timeout: 4))
        choice.tap()
        XCTAssertTrue(app.buttons["この案で置く"].firstMatch.waitForExistence(timeout: 4))
    }

    func testShareShowsMaskedPreview() {
        let share = app.buttons["空き枠を共有"]
        XCTAssertTrue(scrollTo(share))
        share.tap()
        XCTAssertTrue(app.navigationBars["空き枠を共有"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["相手から見える表示"].waitForExistence(timeout: 4) || app.staticTexts["相手から見える表示".uppercased()].exists)
        let anyBlock = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@", "空き", "予定あり")).firstMatch
        XCTAssertTrue(anyBlock.waitForExistence(timeout: 4))
        app.buttons["閉じる"].tap()
    }

    func testWeeklySatisfactionIsOneTap() {
        let good = app.buttons["よかった"]
        XCTAssertTrue(scrollTo(good))
        good.tap()
        XCTAssertTrue(app.buttons["よかった"].isSelected)
        XCTAssertEqual(app.alerts.count, 0)
    }

    private func scrollTo(_ element: XCUIElement) -> Bool {
        for _ in 0..<6 {
            if element.waitForExistence(timeout: 1), element.isHittable { return true }
            app.swipeUp()
        }
        return element.exists && element.isHittable
    }

    private func completeOnboardingIfNeeded() {
        let next = app.buttons["次へ"]
        guard next.waitForExistence(timeout: 4) else { return }
        for _ in 0..<5 {
            XCTAssertTrue(next.waitForExistence(timeout: 3))
            next.tap()
        }
        let start = app.buttons["余白を置いて始める"]
        XCTAssertTrue(start.waitForExistence(timeout: 3))
        start.tap()
    }
}
