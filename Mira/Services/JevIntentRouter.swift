import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Only an intent crosses this boundary; dates, people, titles and actions remain local.
struct JevIntentDecision: Codable, Sendable {
    let intent: ConversationIntent
    let confidence: Double
    let probability: Double
    let model: String

    var isUsable: Bool {
        intent != .unknown && confidence.isFinite && probability.isFinite
            && (0.80...1).contains(confidence) && (0.80...1).contains(probability)
            && !model.isEmpty && model.count <= 80
    }
}

struct JevConfiguration: Equatable, Sendable {
    let endpoint: URL
    let clientToken: String

    static func endpoint(from text: String) -> URL? {
        guard let components = URLComponents(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              components.scheme?.lowercased() == "https",
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil,
              components.path == "/v1/intent" else { return nil }
        return components.url
    }

    static func validToken(_ token: String) -> Bool {
        (32...512).contains(token.utf8.count)
            && token.unicodeScalars.allSatisfy { (33...126).contains($0.value) }
    }
}

protocol JevConfigurationProviding: Sendable {
    func configuration() -> JevConfiguration?
}

protocol JevIntentRouting: Sendable {
    func classify(text: String, hasContext: Bool) async -> JevIntentDecision?
}

struct JevIntentRouter: JevIntentRouting {
    let configurationProvider: any JevConfigurationProviding
    let session: URLSession

    init(
        configurationProvider: any JevConfigurationProviding = JevSettingsStore.shared,
        session: URLSession = JevIntentRouter.makeSession()
    ) {
        self.configurationProvider = configurationProvider
        self.session = session
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 3
        configuration.timeoutIntervalForResource = 4
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration, delegate: JevNoRedirectDelegate(), delegateQueue: nil)
    }

    func classify(text: String, hasContext: Bool) async -> JevIntentDecision? {
        guard !Task.isCancelled,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              text.count <= 2_000, text.utf8.count <= 8_000,
              let configuration = configurationProvider.configuration() else { return nil }
        do {
            var request = URLRequest(url: configuration.endpoint)
            request.httpMethod = "POST"
            request.timeoutInterval = 3
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(configuration.clientToken)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONEncoder().encode(IntentRequest(text: text, hasContext: hasContext))
            let (data, response) = try await session.data(for: request)
            // Turning the feature off or changing its server also invalidates an in-flight result.
            guard !Task.isCancelled, configurationProvider.configuration() == configuration,
                  let response = response as? HTTPURLResponse, response.statusCode == 200,
                  response.mimeType?.lowercased() == "application/json",
                  data.count <= 16_384 else { return nil }
            let decision = try JSONDecoder().decode(JevIntentDecision.self, from: data)
            return decision.isUsable ? decision : nil
        } catch {
            // Never log the input, credentials, URL response body or upstream errors.
            return nil
        }
    }

    private struct IntentRequest: Encodable {
        let text: String
        let hasContext: Bool
    }
}

private final class JevNoRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

/// The optional cloud route can improve a read/consultation flow, but cannot promote
/// an input to a calendar mutation or replace locally extracted dates and constraints.
struct JevAssistedConversationInterpreter: ConversationInterpreting {
    let local: any ConversationInterpreting
    let router: any JevIntentRouting

    init(
        local: any ConversationInterpreting = ProductionConversationInterpreter(),
        router: any JevIntentRouting = JevIntentRouter()
    ) {
        self.local = local
        self.router = router
    }

    func interpret(
        text: String,
        now: Date,
        pinnedContext: ContextSearchResult?,
        searchCandidates: [ContextSearchResult],
        recentTurns: [ConversationTurnSnapshot]
    ) async -> ConversationInterpretation {
        async let decision = router.classify(text: text, hasContext: pinnedContext != nil)
        let interpretation = await local.interpret(
            text: text, now: now, pinnedContext: pinnedContext,
            searchCandidates: searchCandidates, recentTurns: recentTurns
        )
        guard let decision = await decision, !Task.isCancelled else { return interpretation }
        return Self.merging(decision, into: interpretation, originalText: text)
    }

    static func merging(
        _ decision: JevIntentDecision,
        into local: ConversationInterpretation,
        originalText: String
    ) -> ConversationInterpretation {
        guard decision.isUsable, decision.intent != local.intent else { return local }
        // A narrowly scoped rollout: cloud decisions never create/update/decline for the user.
        guard [.checkInvitation, .findDates, .askAboutExisting].contains(decision.intent),
              ![.updateExisting, .declineInvitation].contains(local.intent) else { return local }
        if decision.intent == .askAboutExisting && local.matchedContextID == nil { return local }

        // Existing case follow-ups contain local state that deliberately is not sent to the cloud.
        if local.matchedContextID != nil { return local }
        let explicitAction = ["追加して", "登録して", "入れて", "入れといて", "変更して", "ずらして", "断る", "断り", "見送"]
        if explicitAction.contains(where: originalText.contains) { return local }

        var result = local
        result.intent = decision.intent
        result.inferredFields.insert("intent")
        result.source += " + Jev intent"
        // Keep confidence for the whole interpretation local: intent confidence says nothing
        // about whether a date or duration was read correctly.
        // Resolve only the intent question. A local clarification about excluded dates,
        // missing times, or another constraint must survive a successful cloud route.
        let isIntentQuestion = local.clarificationQuestion?.contains("どうしたい") == true
        if local.intent == .unknown && (!local.needsClarification || isIntentQuestion) {
            result.needsClarification = local.durationBucket == nil
            result.clarificationQuestion = result.needsClarification ? "どのくらいの予定になりそう？" : nil
            result.clarificationOptions = result.needsClarification ? DurationBucket.allCases.map(\.title) : []
        }
        return result
    }
}
