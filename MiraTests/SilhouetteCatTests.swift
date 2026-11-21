import SwiftUI
import XCTest
@testable import Mira

final class SilhouetteCatTests: XCTestCase {
    @MainActor
    func testRenderPosePreviews() throws {
        for (name, mood) in [("sitting", CatMood.idle), ("loaf", .relaxed), ("peeking", .warning)] {
            let renderer = ImageRenderer(content:
                SilhouetteCatView(mood: mood, size: 300, animates: false)
                    .environment(\.colorScheme, .light)
                    .background(Color(hex: 0xF7F1E8))
            )
            renderer.scale = 1
            let rendered = try XCTUnwrap(renderer.uiImage)
            XCTAssertEqual(rendered.size.width, 300)
            XCTAssertEqual(rendered.size.height, 300)
            let attachment = XCTAttachment(image: rendered)
            attachment.name = "fidelity-\(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testMoodPoses() {
        for mood in [CatMood.idle, .thinking, .inviting, .happy, .celebrating] {
            XCTAssertEqual(SilhouetteCatView.pose(for: mood), .sitting)
        }
        for mood in [CatMood.relaxed, .sleeping] {
            XCTAssertEqual(SilhouetteCatView.pose(for: mood), .loaf)
        }
        for mood in [CatMood.tired, .warning] {
            XCTAssertEqual(SilhouetteCatView.pose(for: mood), .peeking)
        }
    }

    func testThemeRoundTripAndCatBehavior() throws {
        XCTAssertEqual(AppThemeKind.silhouetteCat.rawValue, "silhouetteCat")
        XCTAssertEqual(AppThemeKind(rawValue: "silhouetteCat"), .silhouetteCat)
        let data = try JSONEncoder().encode(AppThemeKind.silhouetteCat)
        XCTAssertEqual(try JSONDecoder().decode(AppThemeKind.self, from: data), .silhouetteCat)
        XCTAssertTrue(AppThemeKind.silhouetteCat.isCat)
        XCTAssertTrue(AppThemeKind.pixelCat.isCat)
        XCTAssertFalse(AppThemeKind.softMinimal.isCat)
        XCTAssertNil(AppThemeKind(rawValue: ""))
        XCTAssertNil(AppThemeKind(rawValue: "unknown"))
    }
}
