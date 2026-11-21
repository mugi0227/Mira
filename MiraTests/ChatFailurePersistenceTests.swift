import XCTest
@testable import Mira

final class ChatFailurePersistenceTests: XCTestCase {
    func testFailureSurvivesConversationEncoding() throws {
        let message = ChatMessage(role: .assistant, text: ChatAnswer.failure, failure: .aiUnavailable)
        let data = try JSONEncoder().encode(message)
        XCTAssertEqual(try JSONDecoder().decode(ChatMessage.self, from: data).failure, .aiUnavailable)
    }

    func testOldConversationWithoutFailureStillDecodes() throws {
        let message = ChatMessage(role: .assistant, text: "いつもの返信")
        let data = try JSONEncoder().encode(message)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "failure")
        let oldData = try JSONSerialization.data(withJSONObject: object)
        XCTAssertNil(try JSONDecoder().decode(ChatMessage.self, from: oldData).failure)
    }
}
