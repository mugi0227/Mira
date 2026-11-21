import XCTest

final class OneLineCatSkinUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-demo", "-ui-theme", "pixelCat", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
    }

    func testSwitchingToOneLineCatShowsTheFullCat() {
        launchHome()
        app.buttons["miraTab-settings"].tap()
        let skinRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "スキン")).firstMatch
        XCTAssertTrue(skinRow.waitForExistence(timeout: 5))
        skinRow.tap()

        let card = app.buttons["One-line Catスキン"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["oneLineCat"].firstMatch.exists)
        card.tap()
        XCTAssertTrue(app.buttons["One-line Catスキン、選択中"].waitForExistence(timeout: 5))
        capture("oneline-skin-picker")

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "One-line Cat")).firstMatch.waitForExistence(timeout: 5))
        capture("oneline-settings")

        app.buttons["miraTab-home"].tap()
        XCTAssertTrue(app.miraChatButton.waitForExistence(timeout: 5))
        capture("oneline-home")

        app.buttons["miraTab-margins"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["oneLineCat"].firstMatch.waitForExistence(timeout: 5))
        capture("oneline-margins")

        app.buttons["miraTab-adjustments"].tap()
        capture("oneline-adjustments")

        app.buttons["miraTab-home"].tap()
        app.miraChatButton.tap()
        XCTAssertTrue(app.descendants(matching: .any)["miraChatInput"].waitForExistence(timeout: 5))
        capture("oneline-chat")
    }


    func testOneLineCatSitsInsideItsCircles() {
        launchHome()
        selectOneLineCat()

        app.buttons["miraTab-home"].tap()
        let companion = app.miraChatButton
        XCTAssertTrue(companion.waitForExistence(timeout: 5))

        companion.tap()
        XCTAssertTrue(app.descendants(matching: .any)["miraChatInput"].waitForExistence(timeout: 5))
        let avatars = app.descendants(matching: .any).matching(identifier: "miraAvatar")
        XCTAssertTrue(avatars.firstMatch.waitForExistence(timeout: 5))
        waitUntilSettled(avatars.firstMatch)
        // The chat opens scrolled to the latest reply, so only check avatars clear of the nav bar.
        let visible = (0..<avatars.count).map { avatars.element(boundBy: $0) }.filter { $0.frame.minY > 120 }
        XCTAssertFalse(visible.isEmpty, "no chat avatar on screen")
        for (index, avatar) in visible.enumerated() {
            assertCatSitsInsideCircle(avatar, name: "oneline-chat-avatar-\(index)")
        }
    }

    private func selectOneLineCat() {
        app.buttons["miraTab-settings"].tap()
        let skinRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "スキン")).firstMatch
        XCTAssertTrue(skinRow.waitForExistence(timeout: 5))
        skinRow.tap()
        let card = app.buttons["One-line Catスキン"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        XCTAssertTrue(app.buttons["One-line Catスキン、選択中"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
    }

    /// Waits for the chat sheet's presentation to finish moving the element.
    private func waitUntilSettled(_ element: XCUIElement) {
        var last = element.frame
        for _ in 0..<20 {
            Thread.sleep(forTimeInterval: 0.25)
            let current = element.frame
            if current == last { return }
            last = current
        }
    }

    /// Finds the cat's line pixels in a circular badge and checks they stay clear of
    /// the rim with the same margin on opposite sides.
    private func assertCatSitsInsideCircle(_ element: XCUIElement, name: String, file: StaticString = #filePath, line: UInt = #line) {
        let shot = element.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        guard let cg = shot.image.cgImage else { return XCTFail("no screenshot", file: file, line: line) }
        let width = cg.width, height = cg.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return XCTFail("could not read pixels", file: file, line: line) }

        let scale = CGFloat(width) / element.frame.width
        let radius = CGFloat(min(width, height)) / 2
        let center = CGPoint(x: CGFloat(width) / 2, y: CGFloat(height) / 2)
        func rgb(_ x: Int, _ y: Int) -> (CGFloat, CGFloat, CGFloat) {
            let i = (y * width + x) * 4
            return (CGFloat(pixels[i]) / 255, CGFloat(pixels[i + 1]) / 255, CGFloat(pixels[i + 2]) / 255)
        }
        func luminance(_ c: (CGFloat, CGFloat, CGFloat)) -> CGFloat { 0.299 * c.0 + 0.587 * c.1 + 0.114 * c.2 }

        let samples = (0..<12).map { step -> CGFloat in
            let angle = CGFloat(step) * .pi / 6
            return luminance(rgb(Int(center.x + cos(angle) * radius * 0.88), Int(center.y + sin(angle) * radius * 0.88)))
        }.sorted()
        let fill = samples[samples.count / 2]

        // The attention dot sits on the top-trailing corner of the companion button.
        let dotSide = 14 * scale
        var minX = CGFloat.infinity, maxX = -CGFloat.infinity, minY = CGFloat.infinity, maxY = -CGFloat.infinity
        var farthest: CGFloat = 0
        var inkCount = 0
        for y in 0..<height {
            for x in 0..<width {
                let px = CGFloat(x), py = CGFloat(y)
                let distance = hypot(px - center.x, py - center.y)
                guard distance < radius - 2.5 * scale else { continue }
                if px > CGFloat(width) - dotSide && py < dotSide { continue }
                let c = rgb(x, y)
                let saturation = max(c.0, c.1, c.2) - min(c.0, c.1, c.2)
                guard abs(luminance(c) - fill) > 0.35, saturation < 0.25 else { continue }
                inkCount += 1
                farthest = max(farthest, distance)
                minX = min(minX, px); maxX = max(maxX, px); minY = min(minY, py); maxY = max(maxY, py)
            }
        }

        XCTAssertGreaterThan(inkCount, width * height / 100, "\(name): no cat lines found", file: file, line: line)
        guard inkCount > 0 else { return }
        let rimGap = (radius - farthest) / scale
        XCTAssertGreaterThanOrEqual(rimGap, max(2, element.frame.width * 0.06), "\(name): cat comes within \(rimGap)pt of the rim", file: file, line: line)
        let left = (minX - (center.x - radius)) / scale, right = (center.x + radius - maxX) / scale
        let top = (minY - (center.y - radius)) / scale, bottom = (center.y + radius - maxY) / scale
        XCTAssertLessThanOrEqual(abs(left - right), 3, "\(name): left \(left)pt vs right \(right)pt", file: file, line: line)
        XCTAssertLessThanOrEqual(abs(top - bottom), 3, "\(name): top \(top)pt vs bottom \(bottom)pt", file: file, line: line)
    }

    private func launchHome() {
        app.launch()
        let recommended = app.buttons["おすすめを確認"]
        if recommended.waitForExistence(timeout: 5) {
            recommended.tap()
            let start = app.buttons["余白を置いて始める"]
            XCTAssertTrue(start.waitForExistence(timeout: 5))
            start.tap()
        }
        XCTAssertTrue(app.miraChatButton.waitForExistence(timeout: 12))
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
