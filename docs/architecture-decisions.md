# Architecture Decisions

## ADR-001 — XcodeGen

The repository stores `project.yml` rather than a manually generated `.xcodeproj`. This keeps the empty-repository bootstrap reviewable and deterministic.

## ADR-002 — Local-first demo

SwiftData is the only data store in the demo. EventKit and CloudKit are deliberately deferred behind future adapter boundaries.

## ADR-003 — AI as semantic adapter

Foundation Models may classify event meaning and word advice. Deterministic engines own every schedule decision.

## ADR-004 — Explicit learning only

User corrections can create load rules. Movement, rejection, inactivity, and ignored suggestions do not.

## ADR-005 — Reproducible demo clock

All seeded behavior uses a fixed Tokyo clock so future dates and video flows do not drift.

## ADR-006 — Theme structure remains stable

Soft Minimal and Pixel Cat share layout and functionality. Themes may change semantic colors, shape, motion, assistant identity, and voice—but not navigation or feature availability.
