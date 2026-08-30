import XCTest
@testable import Mira

final class PixelCatAssetMappingTests: XCTestCase {
    func testEveryMoodMapsToItsProductionAsset() {
        XCTAssertEqual(CatMood.idle.assetName, "PixelCatIdle")
        XCTAssertEqual(CatMood.relaxed.assetName, "PixelCatRelaxed")
        XCTAssertEqual(CatMood.sleeping.assetName, "PixelCatSleeping")
        XCTAssertEqual(CatMood.thinking.assetName, "PixelCatThinking")
        XCTAssertEqual(CatMood.tired.assetName, "PixelCatWorried")
        XCTAssertEqual(CatMood.warning.assetName, "PixelCatWorried")
        XCTAssertEqual(CatMood.happy.assetName, "PixelCatHappy")
        XCTAssertEqual(CatMood.celebrating.assetName, "PixelCatCelebrating")
        XCTAssertEqual(CatMood.inviting.assetName, "PixelCatInviting")
    }
}
