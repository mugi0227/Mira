#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Clarification can carry exact local-search results without asking the model.
path = ROOT / "Mira/Domain/ConversationPreviewModels.swift"
text = path.read_text(encoding="utf-8")
old = '''struct ConversationClarification: Identifiable, Hashable, Sendable {
    var id = UUID()
    var caseID: UUID?
    var question: String
    var options: [String]
    var originalText: String
}
'''
new = '''struct ConversationClarification: Identifiable, Hashable, Sendable {
    var id = UUID()
    var caseID: UUID?
    var question: String
    var options: [String]
    var originalText: String
    var contextOptions: [ContextSearchResult] = []
}
'''
if old in text:
    text = text.replace(old, new, 1)
path.write_text(text, encoding="utf-8")

path = ROOT / "Mira/App/MiraStore+Conversation.swift"
text = path.read_text(encoding="utf-8")
old = '''        let effectivePinned = pinnedContext ?? activeContext
        let recentTurns = conversationCase(id: effectivePinned?.relatedCaseID)?.turns ?? []

        let resolvedContext = effectivePinned ?? resolvedAutomaticContext(from: automaticCandidates)
'''
new = '''        let effectivePinned = pinnedContext ?? activeContext
        let recentTurns = conversationCase(id: effectivePinned?.relatedCaseID)?.turns ?? []

        if effectivePinned == nil,
           needsContextDisambiguation(text: text, candidates: automaticCandidates) {
            let options = Array(automaticCandidates.prefix(3))
            activeClarification = ConversationClarification(
                caseID: nil,
                question: "どの予定のこと？",
                options: options.map(\\.title),
                originalText: text,
                contextOptions: options
            )
            return
        }

        let resolvedContext = effectivePinned ?? resolvedAutomaticContext(from: automaticCandidates)
'''
if old in text:
    text = text.replace(old, new, 1)

old = '''    func answerClarification(_ option: String) async {
        guard let clarification = activeClarification else { return }
        activeClarification = nil
        if let caseID = clarification.caseID {
            activeConversationCaseID = caseID
        }
        await handleConversationInput("\\(clarification.originalText) \\(option)")
    }
'''
new = '''    func answerClarification(_ option: String) async {
        guard let clarification = activeClarification else { return }
        activeClarification = nil

        if let selectedContext = clarification.contextOptions.first(where: { $0.title == option }) {
            pinContext(selectedContext)
            await handleConversationInput(clarification.originalText)
            return
        }

        if let caseID = clarification.caseID {
            activeConversationCaseID = caseID
        }
        await handleConversationInput("\\(clarification.originalText) \\(option)")
    }
'''
if old in text:
    text = text.replace(old, new, 1)

marker = '''    private func resolvedAutomaticContext(from candidates: [ContextSearchResult]) -> ContextSearchResult? {
'''
helper = '''    private func needsContextDisambiguation(
        text: String,
        candidates: [ContextSearchResult]
    ) -> Bool {
        guard candidates.count >= 2,
              let first = candidates.first,
              first.score >= 45 else { return false }
        let second = candidates[1]
        guard first.score - second.score < 18 else { return false }
        let referenceWords = [
            "の件", "のやつ", "のこと", "あれ", "それ", "変更", "になった",
            "夜は", "昼は", "朝は", "断る", "ずら", "候補", "送る文"
        ]
        return referenceWords.contains(where: text.contains)
    }

'''
if "private func needsContextDisambiguation" not in text and marker in text:
    text = text.replace(marker, helper + marker, 1)

path.write_text(text, encoding="utf-8")
print("Deterministic context disambiguation applied.")
