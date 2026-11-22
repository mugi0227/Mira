import Foundation

enum ChatAnswer {
    static let failure = "今はAIを利用できません。少し時間をおいて、もう一度お試しください。"
    static let characterLimit = 500
    static let lineLimit = 8

    static func trimmed(_ text: String) -> String {
        var seen = Set<String>()
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
        let compact = lines.prefix(lineLimit).joined(separator: "\n")
        guard compact.count > characterLimit else { return compact }
        let prefix = String(compact.prefix(characterLimit - 1))
        if let end = prefix.lastIndex(where: { "。！？\n".contains($0) }) {
            return String(prefix[...end]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return prefix + "…"
    }

    static func markdown(_ text: String) -> AttributedString {
        let bullets = text.components(separatedBy: "\n").map { line in
            let clean = line.trimmingCharacters(in: .whitespaces)
            return clean.hasPrefix("* ") || clean.hasPrefix("- ") ? "• " + clean.dropFirst(2) : line
        }.joined(separator: "\n")
        let parsed = (try? AttributedString(markdown: bullets,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(bullets)
        guard String(parsed.characters).contains("**") else { return parsed }
        return AttributedString(String(parsed.characters).replacingOccurrences(of: "**", with: ""))
    }

    static func date(_ date: Date) -> String {
        DateFormatter.mira("yyyy年M月d日（EEEE）").string(from: date)
    }
}
