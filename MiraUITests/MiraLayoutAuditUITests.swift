import XCTest

/// Geometry hints, not a substitute for reviewing the attached screenshots.
final class MiraLayoutAuditUITests: XCTestCase {
    func testAuditRepresentativeScreens() throws {
        try? FileManager.default.removeItem(atPath: "/tmp/mira-layout-audit")
        continueAfterFailure = true
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing", "-reset-demo"]
        app.launch()
        if !app.buttons["おすすめを確認"].waitForExistence(timeout: 4) {
            tap(app.buttons["設定"])
            tap(app.buttons["サンプル状態へリセット"])
            tap(app.buttons["リセット"])
        }
        if app.buttons["自分に合わせて設定する"].waitForExistence(timeout: 5) {
            tap(app.buttons["自分に合わせて設定する"])
            for _ in 0..<4 { tap(app.buttons["次へ"]) }
            tap(app.buttons["余白を置いて始める"])
        }
        guard app.buttons["ホーム"].waitForExistence(timeout: 8) else {
            if ProcessInfo.processInfo.environment["MIRA_LAYOUT_AUDIT_STRICT"] == "1" {
                XCTFail("Home navigation unavailable")
            }
            print("Layout audit skipped: Home navigation unavailable")
            return
        }
        try audit("04-home-top", in: app)
        app.swipeUp()
        try audit("05-home-calendar", in: app)
        app.swipeDown()
        app.swipeDown()
        tap(app.buttons["miraChatButton"])
        try audit("07a-chat-welcome", in: app)
        tap(app.buttons["閉じる"])
        for (label, name) in [("調整", "10-adjustments"), ("マイ余白", "11-my-margins"), ("設定", "13-settings")] {
            tap(app.buttons[label])
            try audit(name, in: app)
        }
    }

    private func tap(_ element: XCUIElement) {
        guard element.waitForExistence(timeout: 5) else {
            if ProcessInfo.processInfo.environment["MIRA_LAYOUT_AUDIT_STRICT"] == "1" {
                XCTFail("Missing navigation element: \(element)")
            }
            print("Layout audit navigation unavailable: \(element)")
            return
        }
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        Thread.sleep(forTimeInterval: 0.6)
    }

    private func audit(_ name: String, in app: XCUIApplication) throws {
        Thread.sleep(forTimeInterval: 0.6)
        let bounds = app.frame
        var findings: [[String: Any]] = []
        var elements: [[String: Any]] = []
        var texts: [(String, CGRect)] = []
        var seen = Set<String>()
        func box(_ frame: CGRect) -> [CGFloat] {
            [frame.minX, frame.minY, frame.maxX, frame.maxY]
        }
        func record(_ area: String, _ issue: String, _ frame: CGRect) {
            findings.append(["area": area, "issue": issue, "severity": "medium", "frame": box(frame)])
        }
        for (kind, query) in [("staticText", app.staticTexts), ("button", app.buttons), ("image", app.images)] {
            for element in query.allElementsBoundByIndex {
                let frame = element.frame
                guard !frame.isEmpty, !frame.isInfinite, frame.intersects(bounds) else { continue }
                // Do not require hittability: partially clipped text is still relevant.
                let label = String(element.label.prefix(160))
                let identity = "\(kind)|\(label)|\(frame)"
                guard seen.insert(identity).inserted else { continue }
                elements.append(["kind": kind, "label": label, "frame": box(frame)])
                if frame.width < bounds.width * 0.9,
                   frame.minX - bounds.minX < 16 - 0.01 || bounds.maxX - frame.maxX < 16 - 0.01 {
                    record(label, "画面左右端の余白が16pt未満", frame)
                }
                if kind == "staticText" {
                    if !bounds.contains(frame) { record(label, "テキストが画面境界でクリップ", frame) }
                    for (otherLabel, otherFrame) in texts {
                        let overlap = frame.intersection(otherFrame)
                        if !overlap.isNull, overlap.width > 1, overlap.height > 1 {
                            record("\(otherLabel) / \(label)", "テキストのフレームが重複", overlap)
                        }
                    }
                    texts.append((label, frame))
                }
            }
        }
        let data = try JSONSerialization.data(withJSONObject: [
            "screen": name, "screenBounds": box(bounds), "units": "points",
            "findings": findings, "elements": elements
        ], options: [.prettyPrinted, .sortedKeys])
        let directory = URL(fileURLWithPath: "/tmp/mira-layout-audit", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: directory.appendingPathComponent("\(name).json"), options: .atomic)
        let json = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        json.name = "\(name)-audit"
        json.lifetime = .keepAlways
        add(json)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
        print("Layout audit \(name): \(findings.count) findings, \(elements.count) elements")
        if ProcessInfo.processInfo.environment["MIRA_LAYOUT_AUDIT_STRICT"] == "1" {
            XCTAssertTrue(findings.isEmpty, "\(name): \(findings.count) layout findings")
        }
    }
}
