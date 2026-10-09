import XCTest

/// Captures representative screens for visual review.
/// Every step is best-effort: a missing element skips that screen instead of
/// failing the run, so one layout change never costs the remaining captures.
final class MiraScreenshotUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    func testCaptureRepresentativeScreens() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing", "-reset-demo"]
        app.launch()

        ensureOnboarding(in: app)
        capture("01-onboarding-welcome")

        if tap(app.buttons["自分に合わせて設定する"], in: app) {
            for _ in 0..<2 { tapNext(in: app) }
            if app.staticTexts["普段、予定を入れたくない時間はある？"].waitForExistence(timeout: 4) {
                capture("02-onboarding-base-hours")
            }
            tapNext(in: app)
            tapNext(in: app)
            capture("03-onboarding-ready")
            tap(app.buttons["余白を置いて始める"], in: app)
        }

        _ = app.buttons["ホーム"].waitForExistence(timeout: 8)
        settle(1.0)
        capture("04-home-top")
        app.swipeUp()
        settle()
        capture("05-home-calendar")
        captureCalendarInteractions(in: app, prefix: "06")
        app.swipeDown()
        app.swipeDown()
        settle()

        if tap(app.buttons["friendViewToggle"], in: app) {
            settle(0.8)
            capture("08-friend-view")
            tap(app.buttons["friendViewToggle"], in: app)
        }

        if tap(app.buttons["miraCompanionButton"], in: app) {
            settle(0.8)
            capture("07a-chat-welcome")
            let suggestions = app.buttons.matching(identifier: "chatSuggestion")
            if suggestions.count > 1 {
                tap(suggestions.element(boundBy: 1), in: app)
                _ = app.staticTexts["chatAssistantText"].firstMatch.waitForExistence(timeout: 20)
                settle(1.0)
                capture("07b-chat-open-slots")
                let slot = app.buttons.matching(NSPredicate(format: "label CONTAINS '–'")).firstMatch
                if tap(slot, in: app, timeout: 2) {
                    settle(2.0)
                    capture("07c-chat-event-proposal")
                }
            }
            tap(app.buttons["閉じる"], in: app)
        }

        if tap(app.buttons["調整"], in: app) {
            capture("10-adjustments")
        }

        if tap(app.buttons["マイ余白"], in: app) {
            capture("11-my-margins")
            let baseHours = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "普段は予定を置かない時間")).firstMatch
            if tap(baseHours, in: app, avoidingTabBar: true), app.navigationBars["基本時間"].waitForExistence(timeout: 3) {
                capture("12-base-hours-editor")
                tap(app.buttons["キャンセル"], in: app)
            }
        }

        guard tap(app.buttons["設定"], in: app) else { return }
        capture("13-settings")
        app.swipeUp()
        settle()
        capture("13b-settings-calendar-display")
        // Week start must flip the home grid too: capture it on Sunday, then restore.
        let weekPicker = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "週の始まり")).firstMatch
        if tap(weekPicker, in: app), tap(app.buttons["日曜始まり"], in: app, timeout: 2) {
            capture("13c-settings-sunday-start")
            if tap(app.buttons["ホーム"], in: app) {
                capture("13d-home-sunday-start")
                tap(app.buttons["設定"], in: app)
            }
            let restore = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "週の始まり")).firstMatch
            if tap(restore, in: app) { tap(app.buttons["月曜始まり"], in: app, timeout: 2) }
        }
        app.swipeDown()
        settle()

        if tap(app.staticTexts["余白のおまかせ"], in: app),
           app.navigationBars["余白のおまかせ"].waitForExistence(timeout: 3) {
            capture("14-margin-comfort-settings")
            tap(app.navigationBars["余白のおまかせ"].buttons.firstMatch, in: app)
        }

        if tap(app.staticTexts["スキン"], in: app), app.navigationBars["スキン"].waitForExistence(timeout: 3) {
            capture("15-skin-picker")
            let softMinimal = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Soft Minimal")).firstMatch
            if tap(softMinimal, in: app) {
                tap(app.navigationBars["スキン"].buttons.firstMatch, in: app)
                if tap(app.buttons["ホーム"], in: app) {
                    capture("16-soft-minimal-home-top")
                    app.swipeUp()
                    settle()
                    capture("17-soft-minimal-home-calendar")
                    app.swipeDown()
                    app.swipeDown()
                }
                tap(app.buttons["設定"], in: app)
            } else {
                tap(app.navigationBars["スキン"].buttons.firstMatch, in: app)
            }
        }

        if tap(app.staticTexts["古いカレンダーから移行"], in: app),
           app.navigationBars["カレンダーの引っ越し"].waitForExistence(timeout: 3) {
            capture("18-legacy-import-intro")
        }
    }

    /// Day timeline, event detail and the add-event form are where the
    /// everyday "add / recolor / move" requests are judged.
    private func captureCalendarInteractions(in app: XCUIApplication, prefix: String) {
        let busyDay = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@ AND NOT (label CONTAINS %@)", "9月", "予定なし")
        ).element(boundBy: 3)

        if busyDay.waitForExistence(timeout: 2) {
            let strip = busyDay.buttons.firstMatch
            if strip.exists, tap(strip, in: app) {
                if app.navigationBars["詳細"].waitForExistence(timeout: 3) {
                    capture("\(prefix)a-event-detail")
                    if tap(app.buttons["eventColor-mint"], in: app, timeout: 1) {
                        capture("\(prefix)a2-event-detail-color-picked")
                    }
                    app.swipeUp()
                    settle()
                    capture("\(prefix)b-event-detail-lower")
                }
                if tap(app.buttons["quickMove1"], in: app, timeout: 1) {
                    settle(1.2)
                    capture("\(prefix)b2-after-quick-move")
                } else {
                    dismissSheet(in: app)
                }
            }

            if tap(busyDay, in: app) {
                settle(0.8)
                capture("\(prefix)c-day-timeline")
                app.swipeUp()
                settle()
                capture("\(prefix)d-day-timeline-lower")
                tap(app.navigationBars.buttons.firstMatch, in: app)
            }
        }

        app.swipeDown()
        app.swipeDown()
        settle()
        if tap(app.buttons["追加メニュー"], in: app), tap(app.buttons["予定・余白を追加"], in: app) {
            settle(0.8)
            capture("\(prefix)e-add-event-form")
            app.swipeUp()
            settle()
            capture("\(prefix)f-add-event-form-lower")
            if tap(app.buttons["下書きを削除"], in: app, timeout: 1) {
                tap(app.alerts.buttons["削除"], in: app, timeout: 2)
            } else {
                dismissSheet(in: app)
            }
        }
    }

    private func dismissSheet(in app: XCUIApplication) {
        for label in ["キャンセル", "閉じる", "完了"] where app.buttons[label].exists {
            tap(app.buttons[label], in: app)
            return
        }
        app.swipeDown(velocity: .fast)
        settle()
    }

    private func tapNext(in app: XCUIApplication) {
        tap(app.buttons["次へ"], in: app)
    }

    private func ensureOnboarding(in app: XCUIApplication) {
        if app.buttons["おすすめを確認"].waitForExistence(timeout: 4) { return }
        guard tap(app.buttons["設定"], in: app, timeout: 6),
              tap(app.buttons["サンプル状態へリセット"], in: app),
              tap(app.buttons["リセット"], in: app) else { return }
        _ = app.buttons["おすすめを確認"].waitForExistence(timeout: 6)
        settle()
    }

    /// Taps by coordinate so XCUITest never attempts its own scroll-to-visible,
    /// which fails for rows that sit under the floating tab bar.
    @discardableResult
    private func tap(
        _ element: XCUIElement,
        in app: XCUIApplication,
        timeout: TimeInterval = 4,
        avoidingTabBar: Bool = false
    ) -> Bool {
        guard element.waitForExistence(timeout: timeout) else { return false }
        var attempts = 0
        while attempts < 3,
              !element.isHittable || (avoidingTabBar && element.frame.midY > app.frame.maxY - 120) {
            app.swipeUp()
            settle(0.4)
            attempts += 1
        }
        guard element.exists, !element.frame.isEmpty else { return false }
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        settle()
        return true
    }

    private func capture(_ name: String) {
        settle(0.35)
        let screenshot = XCUIScreen.main.screenshot()
        let directory = URL(fileURLWithPath: "/tmp/mira-screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(
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
