import XCTest

final class ConfirmedAdjustmentUITests: XCTestCase {
    func testConfirmedAdjustmentMovesOutOfInProgress() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing", "-reset-demo", "-seed-confirmed-adjustment", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        let next = app.buttons["おすすめを確認"]
        if next.waitForExistence(timeout: 4) {
            next.tap()
            let start = app.buttons["余白を置いて始める"]
            XCTAssertTrue(start.waitForExistence(timeout: 3))
            start.tap()
        }
        let tab = app.buttons["miraTab-adjustments"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        let picker = app.segmentedControls.firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertTrue(picker.buttons["調整中"].isSelected)
        let confirmed = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "確定したランチ")).firstMatch
        XCTAssertFalse(confirmed.exists)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "カフェに行く")).firstMatch.exists)

        picker.buttons["確定済み"].tap()
        XCTAssertTrue(confirmed.waitForExistence(timeout: 5))
        XCTAssertFalse(confirmed.label.contains("候補"))
        XCTAssertTrue(confirmed.label.contains("確定済み"))
        capture("adjustments-confirmed")
        confirmed.tap()
        XCTAssertTrue(app.navigationBars["日程調整"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '候補 0件' OR label CONTAINS '候補0件'")).firstMatch.exists)
        app.buttons["閉じる"].tap()
        picker.buttons["調整中"].tap()
        XCTAssertFalse(confirmed.exists)
        capture("adjustments-in-progress")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
