#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

path = ROOT / "Mira/App/MiraStore+ConversationLinking.swift"
text = path.read_text(encoding="utf-8")
text = text.replace("itemEntity?.conversationCaseID", "itemEntity.conversationCaseID")
text = text.replace("itemEntity?.updatedAt", "itemEntity.updatedAt")
path.write_text(text, encoding="utf-8")

path = ROOT / "Mira/App/MiraStore+Conversation.swift"
text = path.read_text(encoding="utf-8")
old = '''        context.insert(entity)
        try? context.save()
        try? refresh()
'''
new = '''        context.insert(entity)
        linkContextRecord(resolvedContext, to: entity.id)
        try? context.save()
        try? refresh()
'''
# Replace only inside ensureConversationCase. There may be an earlier insertion;
# locate the method first to avoid touching unrelated flows.
method = text.find("    private func ensureConversationCase(")
if method >= 0:
    position = text.find(old, method)
    if position >= 0 and new not in text[position:position + len(new) + 80]:
        text = text[:position] + new + text[position + len(old):]
path.write_text(text, encoding="utf-8")
print("Persistent context linking applied.")
