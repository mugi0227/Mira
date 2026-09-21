---
type: "diagnostic"
date: "2026-08-30T04:48:10.258071+00:00"
question: "Why does the cat on the My Margins page literally move from the top to the bottom of the screen?"
contributor: "graphify"
outcome: "useful"
source_nodes: ["PixelCatView", "MarginsView", "MainTabView", "AppRootView", "MiraMotion"]
---

# Q: Why does the cat on the My Margins page literally move from the top to the bottom of the screen?

## Answer

The checked-in MarginsView and its TabView/NavigationStack parents contain no screen-height offset or position animation. PixelCatView is the only repeating animation: a floating state is set in onAppear and a repeatForever implicit animation is attached to the whole artwork view, even though its declared offset is only -2 to +2 points. The PNGs are static, consistently sized 128/256/384, and contain no APNG chunks. Therefore full-screen travel cannot come from the asset or declared offset; it is most plausibly a SwiftUI runtime layout transaction/initial placement being captured by the unbounded repeatForever modifier after the artwork wrapper change. The safe remedy is to remove this stateful implicit repeatForever animation or replace it with a layout-isolated TimelineView/phase animation inside a fixed frame. Also verify the installed build commit because the local and origin branch both point at 91ea9ea.

## Outcome

- Signal: useful

## Source Nodes

- PixelCatView
- MarginsView
- MainTabView
- AppRootView
- MiraMotion