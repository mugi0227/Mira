import XCTest
@testable import Mira

final class JevIntentRouterTests: XCTestCase {
    func testOnlyHTTPSIntentEndpointWithoutQueryOrEmbeddedCredentialsIsAllowed() {
        XCTAssertNotNil(JevConfiguration.endpoint(from: "https://mira.example/v1/intent"))
        for endpoint in ["http://mira.example/v1/intent", "https://user:pass@mira.example/v1/intent",
                         "https://mira.example/v1/intent?token=private", "https://mira.example/v1/intent#fragment",
                         "https://mira.example/", "file:///v1/intent"] {
            XCTAssertNil(JevConfiguration.endpoint(from: endpoint), endpoint)
        }
        XCTAssertFalse(JevConfiguration.validToken("short"))
        XCTAssertFalse(JevConfiguration.validToken(String(repeating: "x", count: 40) + "\n"))
    }

    func testDisabledConfigurationReturnsNoCloudDecision() async {
        let router = JevIntentRouter(configurationProvider: FixedConfiguration(value: nil), session: mockSession())
        let result = await router.classify(text: "相談したい", hasContext: false)
        XCTAssertNil(result)
    }

    func testAuthenticatedTransportSendsOnlyTextAndContextPresence() async {
        let result = await router(host: "success.example").classify(text: "飲みに誘われた", hasContext: false)
        XCTAssertEqual(result?.intent, .checkInvitation)
    }

    func testTurningOffConfigurationDiscardsAnInFlightAnswer() async {
        let configuration = JevConfiguration(endpoint: URL(string: "https://success.example/v1/intent")!, clientToken: String(repeating: "x", count: 40))
        let router = JevIntentRouter(configurationProvider: ExpiringConfiguration(value: configuration), session: mockSession())
        let result = await router.classify(text: "飲みに誘われた", hasContext: false)
        XCTAssertNil(result)
    }

    func testNetworkFailureInvalidAnswerAndLowConfidenceFallBack() async {
        for host in ["offline.example", "malformed.example", "low.example", "wrongtype.example", "unauthorized.example"] {
            let result = await router(host: host).classify(text: "飲みに誘われた", hasContext: false)
            XCTAssertNil(result, host)
        }
        let long = await router(host: "success.example").classify(text: String(repeating: "あ", count: 2001), hasContext: false)
        XCTAssertNil(long)
    }

    func testIntentRoutingPreservesDateTitleAndExclusions() {
        let local = exampleLocal(intent: .unknown)
        let result = JevAssistedConversationInterpreter.merging(
            decision(.checkInvitation), into: local, originalText: "金曜誘われたけど今週きつい"
        )
        XCTAssertEqual(result.intent, .checkInvitation)
        XCTAssertEqual(result.title, local.title)
        XCTAssertEqual(result.candidateDates, local.candidateDates)
        XCTAssertEqual(result.exactStartDate, local.exactStartDate)
        XCTAssertEqual(result.exactEndDate, local.exactEndDate)
        XCTAssertEqual(result.explicitConstraints, ["夜を除外"])
        XCTAssertEqual(result.durationBucket, .short)
        XCTAssertEqual(result.timeBands, [.midday])
        XCTAssertEqual(result.confidence, local.confidence)
        XCTAssertTrue(result.inferredFields.contains("intent"))
        XCTAssertFalse(result.needsClarification)
    }

    func testRoutingStillAsksForMissingDuration() {
        let result = JevAssistedConversationInterpreter.merging(
            decision(.findDates), into: .unknown("来月何かしたい"), originalText: "来月何かしたい"
        )
        XCTAssertEqual(result.intent, .findDates)
        XCTAssertTrue(result.needsClarification)
        XCTAssertTrue(result.clarificationOptions.contains("半日"))
    }

    func testCloudIntentDoesNotDismissALocalDateConstraintQuestion() {
        var local = exampleLocal(intent: .unknown)
        local.candidateDates = []
        local.explicitConstraints = ["土曜を除外"]
        local.needsClarification = true
        local.clarificationQuestion = "除外した曜日以外で、どの期間から探す？"
        local.clarificationOptions = ["来週", "再来週", "来月"]
        let result = JevAssistedConversationInterpreter.merging(
            decision(.findDates), into: local, originalText: "土曜は外して"
        )
        XCTAssertEqual(result.intent, .findDates)
        XCTAssertTrue(result.needsClarification)
        XCTAssertEqual(result.clarificationQuestion, local.clarificationQuestion)
        XCTAssertEqual(result.clarificationOptions, local.clarificationOptions)
        XCTAssertEqual(result.explicitConstraints, local.explicitConstraints)
    }

    func testCloudCannotPromoteConsultationOrNegatedRequestToMutation() {
        for text in ["予定にはまだ入れないで", "もし金曜に会うなら？", "来週に変えるのはやめた", "断らないよ"] {
            for remoteIntent in [ConversationIntent.addEvent, .updateExisting, .declineInvitation] {
                let local = exampleLocal(intent: .checkInvitation)
                let result = JevAssistedConversationInterpreter.merging(decision(remoteIntent), into: local, originalText: text)
                XCTAssertEqual(result, local)
            }
        }
    }

    func testExplicitLocalActionsAndCaseContinuationCannotBeOverridden() {
        for localIntent in [ConversationIntent.updateExisting, .declineInvitation] {
            let local = exampleLocal(intent: localIntent)
            XCTAssertEqual(JevAssistedConversationInterpreter.merging(decision(.findDates), into: local, originalText: "やっぱり来週"), local)
        }
        let explicit = exampleLocal(intent: .addEvent)
        XCTAssertEqual(JevAssistedConversationInterpreter.merging(decision(.checkInvitation), into: explicit, originalText: "明日を追加して"), explicit)
        var followUp = exampleLocal(intent: .findDates)
        followUp.matchedContextID = UUID()
        XCTAssertEqual(JevAssistedConversationInterpreter.merging(decision(.checkInvitation), into: followUp, originalText: "土曜以外なら"), followUp)
    }

    func testUnknownAndUncertainDecisionsLeaveAllLocalFieldsUntouched() {
        let local = exampleLocal(intent: .unknown)
        for remote in [decision(.unknown), JevIntentDecision(intent: .findDates, confidence: 0.79, probability: 0.99, model: "jev-1.13.0"),
                       JevIntentDecision(intent: .findDates, confidence: .nan, probability: 1, model: "jev-1.13.0")] {
            XCTAssertEqual(JevAssistedConversationInterpreter.merging(remote, into: local, originalText: "来週"), local)
        }
    }

    func testWrapperUsesLocalResultWhenCloudReturnsNothing() async {
        let expected = exampleLocal(intent: .findDates)
        let interpreter = JevAssistedConversationInterpreter(local: StubInterpreter(result: expected), router: StubRouter(result: nil))
        let result = await interpreter.interpret(text: "日程を探して", now: Date(), pinnedContext: nil, searchCandidates: [], recentTurns: [])
        XCTAssertEqual(result, expected)
    }

    private func decision(_ intent: ConversationIntent) -> JevIntentDecision {
        JevIntentDecision(intent: intent, confidence: 0.93, probability: 0.96, model: "jev-1.13.0")
    }

    private func exampleLocal(intent: ConversationIntent) -> ConversationInterpretation {
        var result = ConversationInterpretation.unknown("友達とカフェ")
        result.intent = intent
        result.candidateDates = [Date(timeIntervalSince1970: 1_800_000_000)]
        result.exactStartDate = result.candidateDates.first
        result.exactEndDate = result.exactStartDate?.addingTimeInterval(3600)
        result.durationBucket = .short
        result.timeBands = [.midday]
        result.explicitConstraints = ["夜を除外"]
        result.confidence = 0.6
        return result
    }

    private func router(host: String) -> JevIntentRouter {
        let configuration = JevConfiguration(endpoint: URL(string: "https://\(host)/v1/intent")!, clientToken: String(repeating: "x", count: 40))
        return JevIntentRouter(configurationProvider: FixedConfiguration(value: configuration), session: mockSession())
    }

    private func mockSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [JevMockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private struct FixedConfiguration: JevConfigurationProviding {
    let value: JevConfiguration?
    func configuration() -> JevConfiguration? { value }
}

private final class ExpiringConfiguration: JevConfigurationProviding, @unchecked Sendable {
    private let value: JevConfiguration
    private let lock = NSLock()
    private var reads = 0
    init(value: JevConfiguration) { self.value = value }
    func configuration() -> JevConfiguration? {
        lock.lock()
        defer { lock.unlock() }
        reads += 1
        return reads == 1 ? value : nil
    }
}

private struct StubRouter: JevIntentRouting {
    let result: JevIntentDecision?
    func classify(text: String, hasContext: Bool) async -> JevIntentDecision? { result }
}

private struct StubInterpreter: ConversationInterpreting {
    let result: ConversationInterpretation
    func interpret(text: String, now: Date, pinnedContext: ContextSearchResult?, searchCandidates: [ContextSearchResult], recentTurns: [ConversationTurnSnapshot]) async -> ConversationInterpretation { result }
}

private final class JevMockURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { return }
        if url.host == "offline.example" {
            client?.urlProtocol(self, didFailWithError: URLError(.timedOut))
            return
        }
        let payload = requestBody().flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        let validRequest = request.httpMethod == "POST"
            && request.value(forHTTPHeaderField: "Authorization") == "Bearer " + String(repeating: "x", count: 40)
            && payload.map { Set($0.keys) == Set(["text", "hasContext"]) } == true
        let status = validRequest && url.host != "unauthorized.example" ? 200 : 401
        let mime = url.host == "wrongtype.example" ? "text/html" : "application/json"
        let body: String
        if url.host == "malformed.example" {
            body = "{\"intent\":\"deleteEverything\"}"
        } else {
            let confidence = url.host == "low.example" ? "0.4" : "0.93"
            body = "{\"intent\":\"checkInvitation\",\"confidence\":\(confidence),\"probability\":0.96,\"model\":\"jev-1.13.0\"}"
        }
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": mime])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private func requestBody() -> Data? {
        if let data = request.httpBody { return data }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(contentsOf: buffer.prefix(count))
        }
        return data
    }
}
