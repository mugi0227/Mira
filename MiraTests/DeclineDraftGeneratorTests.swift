import XCTest
@testable import Mira

final class DeclineDraftGeneratorTests: XCTestCase {
    func testTemplatesRespectSelectedRelationship() async {
        let generator = TemplateDeclineDraftGenerator()

        let friend = await generator.generate(
            title: "飲み会",
            person: "友達",
            previous: nil,
            softer: false,
            audience: .friend,
            generationIndex: 0
        )
        let supervisor = await generator.generate(
            title: "懇親会",
            person: "上司",
            previous: nil,
            softer: false,
            audience: .supervisor,
            generationIndex: 0
        )

        XCTAssertEqual(friend.audience, .friend)
        XCTAssertEqual(friend.tone, DeclineAudience.friend.toneTitle)
        XCTAssertEqual(supervisor.audience, .supervisor)
        XCTAssertEqual(supervisor.tone, DeclineAudience.supervisor.toneTitle)
        XCTAssertTrue(supervisor.text.contains("ありがとうございます"))
        XCTAssertNotEqual(friend.text, supervisor.text)
    }
}
