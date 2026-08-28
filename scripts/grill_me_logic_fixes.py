#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write(path: str, text: str) -> None:
    (ROOT / path).write_text(text, encoding="utf-8")


# Only real follow-up phrases inherit the currently open case. Independent short
# requests such as 「美容院行きたい」 must create/search another case.
path = "Mira/App/MiraStore+Conversation.swift"
text = read(path)
old = '''        guard now.timeIntervalSince(active.lastActivityAt) < 30 * 60 else { return false }
        if text.count <= 24 { return true }
        let words = ["やっぱ", "じゃあ", "それ", "その件", "夜は", "昼は", "朝は", "土曜", "日曜", "来週なら", "断る文", "送る文"]
        return words.contains(where: text.contains)
'''
new = '''        guard now.timeIntervalSince(active.lastActivityAt) < 30 * 60 else { return false }
        let words = [
            "やっぱ", "じゃあ", "それで", "その件", "夜は", "昼は", "朝は",
            "土曜は", "日曜は", "来週なら", "断る文", "送る文", "なしで",
            "無理", "でお願い", "になった", "に変更", "確定で", "これで送る"
        ]
        return words.contains(where: text.contains)
'''
if old in text:
    text = text.replace(old, new, 1)
write(path, text)

# Strip operation wording and time expressions before the mandatory local
# search. This turns 「焼肉19時からになった」 into a fast title query 「焼肉」.
path = "Mira/Services/CaseSearchEngine.swift"
text = read(path)
old = '''        for wrapper in ["の件", "のやつ", "について", "ってさ", "って", "さー", "さあ"] {
            value = value.replacingOccurrences(of: wrapper, with: " ")
        }
        return value
'''
new = '''        value = value.replacingOccurrences(
            of: "[0-9０-９]{1,2}時(?:[0-9０-９]{1,2}分)?(?:から)?(?:になった|に変更|で)?",
            with: " ",
            options: .regularExpression
        )
        for wrapper in [
            "の件", "のやつ", "について", "ってさ", "って", "さー", "さあ",
            "になった", "に変更", "変更して", "ずらしたい", "断りたい", "断る文",
            "夜はなし", "夜なし", "昼はなし", "朝はなし", "お願い", "どうなった"
        ] {
            value = value.replacingOccurrences(of: wrapper, with: " ")
        }
        return value
'''
if old in text:
    text = text.replace(old, new, 1)
write(path, text)

# Give pasted colloquial invitations a concise case title.
path = "Mira/Services/ConversationAssistantService.swift"
text = read(path)
needle = '''    private func inferTitle(from text: String, context: ContextSearchResult?) -> String {
        if let context, text.count < 24 { return context.title }
'''
replacement = '''    private func inferTitle(from text: String, context: ContextSearchResult?) -> String {
        if let context, text.count < 24 { return context.title }
        if text.contains("飲まん") || text.contains("飲み") { return "飲み" }
        if text.contains("焼肉") { return "焼肉" }
        if text.contains("カフェ") { return "カフェ" }
        if text.contains("ランチ") { return "ランチ" }
'''
if needle in text and replacement not in text:
    text = text.replace(needle, replacement, 1)
write(path, text)

print("Conversation logic refinements applied.")
