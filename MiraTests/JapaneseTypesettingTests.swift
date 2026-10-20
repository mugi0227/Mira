import XCTest
@testable import Mira

/// Kanji such as 今・直・骨 differ between Japanese and Chinese fonts. The app
/// declares Japanese as its language so they are drawn the Japanese way on any device.
final class JapaneseTypesettingTests: XCTestCase {
    func testAppDeclaresJapaneseAsItsLanguage() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleDevelopmentRegion") as? String, "ja")
        XCTAssertEqual(Bundle.main.preferredLocalizations.first, "ja")
    }
}
