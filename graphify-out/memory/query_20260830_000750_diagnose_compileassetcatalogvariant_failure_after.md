---
type: "query"
date: "2026-08-30T00:07:50.866722+00:00"
question: "Diagnose CompileAssetCatalogVariant failure after adding pixel cat assets"
contributor: "graphify"
outcome: "useful"
source_nodes: ["XcodeGen Project Configuration", "iOS CI Workflow", "App"]
---

# Q: Diagnose CompileAssetCatalogVariant failure after adding pixel cat assets

## Answer

Expanded from original query via graph vocabulary: [xcodegen, configuration, project, app, pixelcat]. The iOS CI workflow generates the Mira application target from project.yml, and the newly included Assets.xcassets is compiled as the target asset catalog. Codemagic actool failed because the target requested AppIcon but the catalog had no AppIcon.appiconset. Added a single-size 1024x1024 opaque iOS universal AppIcon set.

## Outcome

- Signal: useful

## Source Nodes

- XcodeGen Project Configuration
- iOS CI Workflow
- App