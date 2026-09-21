---
type: "query"
date: "2026-08-30T04:44:08.828134+00:00"
question: "Why does the cat on the My Margins page oscillate vertically forever?"
contributor: "graphify"
outcome: "useful"
source_nodes: ["MarginsView", "PixelCatView", "MiraMotion"]
---

# Q: Why does the cat on the My Margins page oscillate vertically forever?

## Answer

Expanded from original query via graph vocabulary: [margins, margin, pixel, cat, motion, view, goal, progress]. MarginsView.overviewCard renders PixelCatView at size 72. PixelCatView intentionally owns a floating Boolean state, changes it to true on appear, offsets the whole artwork between y=2 and y=-2, and attaches an easeInOut 1.8-second repeatForever autoreversing animation. Therefore the endless vertical simple harmonic-looking motion is global PixelCatView behavior, not My Margins-specific logic. The intended code amplitude is only 4 points peak-to-peak; screen-height travel would indicate an additional runtime issue and needs a recording.

## Outcome

- Signal: useful

## Source Nodes

- MarginsView
- PixelCatView
- MiraMotion