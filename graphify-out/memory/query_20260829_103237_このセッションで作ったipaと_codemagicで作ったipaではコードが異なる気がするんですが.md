---
type: "query"
date: "2026-08-29T10:32:37.190904+00:00"
question: "このセッションで作ったipaと、codemagicで作ったipaではコードが異なる気がするんですが"
contributor: "graphify"
outcome: "useful"
source_nodes: ["XcodeGen Project Configuration", "iOS CI Workflow", "Mira"]
---

# Q: このセッションで作ったipaと、codemagicで作ったipaではコードが異なる気がするんですが

## Answer

Expanded from original query via graph vocab: [mira, project, configuration, workflow, commit, source, feature]. Confirmed different source branches and different compiled Mira.debug.dylib binaries. GitHub Actions IPA came from commit 054a427 based on 6dbd023 and is version 0.1.0. Codemagic IPA corresponds to the feature/grill-me-q61-q82 build path, is version 0.2.0, and contains new assistant and scheduling symbols absent from the GitHub Actions IPA. Use C:\Users\shuhe\Downloads\Mira-unsigned.ipa, not the older artifact subfolder IPA.

## Outcome

- Signal: useful

## Source Nodes

- XcodeGen Project Configuration
- iOS CI Workflow
- Mira