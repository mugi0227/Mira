import XCTest
@testable import Mira

final class SilhouetteCatTests: XCTestCase {
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
