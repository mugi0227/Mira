# Implementation Status

## Completed

- project scaffold and XcodeGen
- SwiftData entities and local store
- deterministic demo clock
- three-month seed data
- onboarding
- home calendar and daily agenda
- margin goal management and automatic placement
- final-defense and relocation choices
- pending invitations
- adjustment sessions, candidate conflicts, sharing, confirmation
- load and buffer engine
- explicit load correction
- Foundation Models adapter and fallback
- Soft Minimal / Pixel Cat themes
- local notification service
- important people management
- Legacy Calendar Import mock
- unit and UI test sources
- GitHub Actions workflow
- Mira tab: vague request → suggestion, proactive suggestions with notification, apply / dismiss / undo
- trend-based suggestions from Mira's own suggestion history (can be turned off)
- weekly review with self-time vs target and one-tap satisfaction
- availability sharing with masked busy time

## Deferred by design

- EventKit connection
- CloudKit sync
- real OCR
- TestFlight / App Store distribution
- Android
- ToDo

## Verification

- Linux pure-domain build and unit tests: `scripts/domain-tests-linux.sh`
- Full iOS build and XCTest: performed by GitHub Actions on macOS/Xcode
