---
type: "query"
date: "2026-08-29T10:35:14.594601+00:00"
question: "download直下のcodemagic版、やったけどThe name for this app is invalidになった"
contributor: "graphify"
outcome: "useful"
source_nodes: ["XcodeGen Project Configuration", "iOS CI Workflow", "MiraApp"]
---

# Q: download直下のcodemagic版、やったけどThe name for this app is invalidになった

## Answer

Expanded from original query via graph vocab: [mira, app, name, display, configuration, project, xcode, workflow]. The Codemagic IPA uses non-ASCII CFBundleDisplayName 余白. AltStore error 3009 documents that Apple App ID registration rejects non-ASCII app names. Created C:\Users\shuhe\Downloads\Mira-AltStore.ipa with CFBundleDisplayName and CFBundleName changed to ASCII Mira; CFBundleIdentifier, version, and compiled Mira.debug.dylib hash remain unchanged.

## Outcome

- Signal: useful

## Source Nodes

- XcodeGen Project Configuration
- iOS CI Workflow
- MiraApp