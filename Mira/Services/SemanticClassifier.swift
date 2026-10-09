import Foundation

protocol EventSemanticClassifying: Sendable {
    func classify(title: String, startDate: Date, endDate: Date, isAllDay: Bool) async -> EventSemanticClassification
    var availabilityDescription: String { get async }
}

struct RuleBasedSemanticClassifier: EventSemanticClassifying {
    private let engine = LoadEngine()

    func classify(title: String, startDate: Date, endDate: Date, isAllDay: Bool) async -> EventSemanticClassification {
        let evaluation = engine.evaluate(
            title: title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay
        )
        return EventSemanticClassification(
            category: evaluation.category,
            estimatedLoad: evaluation.loadClass,
            likelyOutsideHome: evaluation.likelyOutsideHome,
            estimatedDurationHours: max(1, Int(endDate.timeIntervalSince(startDate) / 3600)),
            confidence: 0.62,
            shortReason: evaluation.reason,
            source: "ルールベース"
        )
    }

    var availabilityDescription: String { get async { "ルールベースで動作中" } }
}

struct HybridSemanticClassifier: EventSemanticClassifying {
    private let fallback = RuleBasedSemanticClassifier()

    func classify(title: String, startDate: Date, endDate: Date, isAllDay: Bool) async -> EventSemanticClassification {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), FoundationModelSemanticClassifier.isAvailable {
            if let result = await FoundationModelSemanticClassifier().classifyIfAvailable(
                title: title,
                startDate: startDate,
                endDate: endDate,
                isAllDay: isAllDay
            ) {
                return result
            }
        }
        #endif
        return await fallback.classify(title: title, startDate: startDate, endDate: endDate, isAllDay: isAllDay)
    }

    var availabilityDescription: String {
        get async {
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *), FoundationModelSemanticClassifier.isAvailable {
                return "Apple Intelligenceのオンデバイスモデルが利用可能"
            }
            #endif
            return "この端末ではルールベースへ自動切替"
        }
    }
}

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
@Generable(description: "A compact classification of a personal calendar event")
private struct GeneratedEventClassification {
    @Guide(description: "One short category such as birthday, travel, social, event, outing, short, home, or other")
    var category: String

    @Guide(description: "One of light, normal, heavy, veryHeavy")
    var load: String

    @Guide(description: "Whether the event probably requires leaving home")
    var likelyOutsideHome: Bool

    @Guide(description: "Estimated occupied hours as an integer from 0 to 24")
    var estimatedDurationHours: Int

    @Guide(description: "Confidence from 0.0 to 1.0")
    var confidence: Double

    @Guide(description: "A short Japanese reason, no more than 24 characters")
    var shortReason: String
}

@available(iOS 26.0, *)
private actor FoundationModelSemanticClassifier {
    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    func classifyIfAvailable(
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool
    ) async -> EventSemanticClassification? {
        guard Self.isAvailable else { return nil }

        let formatter = DateFormatter.mira("EEE HH:mm")

        let session = LanguageModelSession(instructions: """
        You classify personal calendar events for a wellbeing calendar.
        Estimate physical/time load, not emotional importance.
        An all-day flag is unreliable: users often save salon visits or birthdays as all-day.
        Birthdays shown as reminders have very low time load.
        Travel, hiking, festivals and full-day outings are heavy.
        Return Japanese reasoning and never invent personal facts.
        """)

        let prompt = """
        Title: \(title)
        Start: \(formatter.string(from: startDate))
        End: \(formatter.string(from: endDate))
        All day flag: \(isAllDay)
        """

        do {
            let response = try await session.respond(to: prompt, generating: GeneratedEventClassification.self)
            let output = response.content
            return EventSemanticClassification(
                category: output.category,
                estimatedLoad: LoadClass(rawValue: output.load) ?? .normal,
                likelyOutsideHome: output.likelyOutsideHome,
                estimatedDurationHours: min(24, max(0, output.estimatedDurationHours)),
                confidence: min(1, max(0, output.confidence)),
                shortReason: output.shortReason,
                source: "Apple Foundation Models"
            )
        } catch {
            return nil
        }
    }
}
#endif
