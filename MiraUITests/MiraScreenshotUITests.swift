import XCTest

final class MiraScreenshotUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCaptureRepresentativeScreens() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing", "-reset-demo"]
        app.launch()

        try ensureOnboarding(in: app)
        try capture("01-onboarding-welcome")

        let customize = app.buttons["自分に合わせて設定する"]
        if customize.waitForExistence(timeout: 4) {
            customize.tap()
            for _ in 0..<2 { tapNext(in: app) }
            if app.staticTexts["普段、予定を入れたくない時間はある？"].waitForExistence(timeout: 4) {
                try capture("02-onboarding-base-hours")
            }
            tapNext(in: app)
            tapNext(in: app)
            try capture("03-onboarding-ready")

            let start = app.buttons["余白を置いて始める"]
            if start.waitForExistence(timeout: 4) {
                start.tap()
            }
        }

        _ = app.buttons["ホーム"].waitForExistence(timeout: 8)
        settle(1.0)
        try capture("04-home-full-width-calendar")
        try capture("05-home-universal-assistant")

        let adjustments = app.buttons["調整"]
        if adjustments.waitForExistence(timeout: 4) {
            adjustments.tap()
            settle()
            try capture("06-adjustments")
        }

        let margins = app.buttons["マイ余白"]
        if margins.waitForExistence(timeout: 4) {
            margins.tap()
            settle()
            try capture("07-my-margins")
        }

        let baseHours = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "普段は予定を置かない時間")).firstMatch
        if baseHours.waitForExistence(timeout: 2) {
            baseHours.tap()
            if app.navigationBars["基本時間"].waitForExistence(timeout: 3) {
                settle()
                try capture("08-base-hours-editor")
                let cancel = app.buttons["キャンセル"]
                if cancel.exists { cancel.tap() }
                settle()
            }
        }

        let settings = app.buttons["設定"]
        if settings.waitForExistence(timeout: 4) {
            settings.tap()
            settle()
            try capture("09-settings")
        }

        let marginAuto = app.staticTexts["余白のおまかせ"]
        if marginAuto.waitForExistence(timeout: 2) {
            marginAuto.tap()
            if app.navigationBars["余白のおまかせ"].waitForExistence(timeout: 3) {
                settle()
                try capture("10-margin-comfort-settings")
                app.navigationBars["余白のおまかせ"].buttons.firstMatch.tap()
                settle()
            }
        }

        let skinText = app.staticTexts["スキン"]
        if skinText.waitForExistence(timeout: 3) {
            skinText.tap()
            if app.navigationBars["スキン"].waitForExistence(timeout: 3) {
                settle()
                try capture("11-skin-picker")
                app.navigationBars["スキン"].buttons.firstMatch.tap()
                settle()
            }
        }

        let importText = app.staticTexts["古いカレンダーから移行"]
        if importText.waitForExistence(timeout: 3) {
            importText.tap()
            if app.navigationBars["カレンダーの引っ越し"].waitForExistence(timeout: 3) {
                settle()
                try capture("12-legacy-import-intro")
            }
        }
    }

    private func tapNext(in app: XCUIApplication) {
        let next = app.buttons["次へ"]
        if next.waitForExistence(timeout: 4) {
            next.tap()
            settle()
        }
    }

    private func ensureOnboarding(in app: XCUIApplication) throws {
        if app.buttons["おすすめを確認"].waitForExistence(timeout: 4) {
            return
        }

        let settings = app.buttons["設定"]
        if settings.waitForExistence(timeout: 6) {
            settings.tap()
            let reset = app.buttons["サンプル状態へリセット"]
            if reset.waitForExistence(timeout: 4) {
                reset.tap()
                let confirm = app.buttons["リセット"]
                if confirm.waitForExistence(timeout: 4) {
                    confirm.tap()
                    _ = app.buttons["おすすめを確認"].waitForExistence(timeout: 6)
                    settle()
                }
            }
        }
    }

    private func capture(_ name: String) throws {
        settle(0.35)
        let screenshot = XCUIScreen.main.screenshot()
        let directory = URL(fileURLWithPath: "/tmp/mira-screenshots", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try screenshot.pngRepresentation.write(
            to: directory.appendingPathComponent("\(name).png"),
            options: .atomic
        )
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func settle(_ seconds: TimeInterval = 0.6) {
        Thread.sleep(forTimeInterval: seconds)
    }
}
