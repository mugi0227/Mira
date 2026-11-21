import XCTest

final class PeekingCatCardUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-demo", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
    }

    func testOneLineCatPeeksWithoutBlockingTheEvent() {
        checkPeekingCard(theme: "onelineCat")
    }

    func testSilhouetteCatPeeksWithoutBlockingTheEvent() {
        checkPeekingCard(theme: "silhouetteCat")
    }

    func testPeekingCardKeepsItsSpaceWithLargeText() {
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityM"]
        checkPeekingCard(theme: "onelineCat")
    }

    func testSoftMinimalKeepsItsUndecoratedCard() {
        let card = launchCard(theme: "softMinimal")
        let heading = card.staticTexts["次の予定"].firstMatch
        XCTAssertTrue(heading.exists)
        XCTAssertLessThan(heading.frame.minY - card.frame.minY, 28)
        capture("peeking-soft-minimal-unchanged")
    }

    private func checkPeekingCard(theme: String) {
        let card = launchCard(theme: theme)
        let heading = card.staticTexts["次の予定"].firstMatch
        let event = card.buttons.firstMatch
        capture("peeking-\(theme)-layout")
        XCTAssertTrue(heading.exists)
        if app.launchArguments.contains("UICTContentSizeCategoryAccessibilityM") {
            XCTAssertGreaterThan(heading.frame.height, 22, "The card must actually use accessibility text sizing")
        }
        // Accessibility bounds follow the visible artwork (the silhouette PNG
        // has transparent edges), not the entire reserved 28pt layout band.
        XCTAssertGreaterThanOrEqual(heading.frame.minY - card.frame.minY, 40)
        XCTAssertGreaterThanOrEqual(heading.frame.minX - card.frame.minX, 24)
        XCTAssertGreaterThanOrEqual(card.frame.minX - app.frame.minX, 20)
        XCTAssertGreaterThanOrEqual(app.frame.maxX - card.frame.maxX, 20)
        XCTAssertGreaterThanOrEqual(card.frame.maxX - event.frame.maxX, 24)
        XCTAssertGreaterThanOrEqual(event.frame.height, 43.5, "Allow subpixel rounding around the 44pt target")
        XCTAssertTrue(event.isHittable)
        assertCatInkAboveCard(card, heading: heading)
        capture("peeking-\(theme)\(app.launchArguments.contains("UICTContentSizeCategoryAccessibilityM") ? "-large-text" : "")")
        // Decoration is not another VoiceOver stop or button.
        XCTAssertFalse(card.staticTexts["注意を知らせる猫"].exists)
        event.tap()
        XCTAssertTrue(app.buttons["閉じる"].waitForExistence(timeout: 5))
    }

    private func launchCard(theme: String) -> XCUIElement {
        app.launchArguments += ["-ui-theme", theme]
        app.launch()
        let recommended = app.buttons["おすすめを確認"]
        if recommended.waitForExistence(timeout: 5) {
            recommended.tap()
            let start = app.buttons["余白を置いて始める"]
            XCTAssertTrue(start.waitForExistence(timeout: 5))
            start.tap()
        }
        XCTAssertTrue(app.buttons["miraChatButton"].waitForExistence(timeout: 12))
        let card = app.descendants(matching: .any)["homeNextStepCard"].firstMatch
        let scroll = app.scrollViews["homeScroll"]
        for _ in 0..<6 {
            if card.exists, card.frame.minY > scroll.frame.minY + 16,
               card.frame.maxY < scroll.frame.maxY - 12 { break }
            // Use the gutter: the redesigned calendar's event chips are draggable.
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.85))
                .press(forDuration: 0.01, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.2)))
        }
        XCTAssertTrue(card.exists)
        XCTAssertGreaterThan(card.frame.minY, scroll.frame.minY)
        XCTAssertLessThan(card.frame.maxY, scroll.frame.maxY)
        var previous = card.frame
        for _ in 0..<10 {
            Thread.sleep(forTimeInterval: 0.25)
            let current = card.frame
            if abs(current.minY - previous.minY) < 0.5, abs(current.height - previous.height) < 0.5 { break }
            previous = current
        }
        return card
    }

    /// Check the otherwise empty band above the surface, not just the view tree:
    /// a missing/hidden head would still pass the spacing assertions.
    private func assertCatInkAboveCard(_ card: XCUIElement, heading: XCUIElement) {
        let shot = app.screenshot()
        guard let cg = shot.image.cgImage else { return XCTFail("No card screenshot") }
        let width = cg.width, height = cg.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        XCTAssertTrue(drawn)
        let scale = CGFloat(width) / app.frame.width
        // Measure the ear region against the text's fixed surface inset so
        // transparent image edges cannot change the screenshot crop.
        let top = heading.frame.minY - 48
        let sample = (Int((top + 8) * scale) * width + Int((card.frame.minX + 8) * scale)) * 4
        var ink = 0
        for y in Int(top * scale)..<Int((top + 19) * scale) {
            for x in Int((card.frame.maxX - 88) * scale)..<Int((card.frame.maxX - 32) * scale) {
                let index = (y * width + x) * 4
                let difference = (0..<3).reduce(0) { $0 + abs(Int(pixels[index + $1]) - Int(pixels[sample + $1])) }
                if difference > 90 { ink += 1 }
            }
        }
        XCTAssertGreaterThan(ink, 12, "The cat should be drawn above, not hidden behind the surface")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
