# Architecture

```text
SwiftUI View
  ↓
MiraStore / Feature state
  ↓
Domain Engines
  ├─ SchedulerEngine
  ├─ LoadEngine
  ├─ ProtectionEngine
  ├─ ConflictEngine
  ├─ FreeEveningEngine
  └─ AssistantEngine
  ↓
SwiftData / Foundation Models / UserNotifications
```

## Boundaries

- UI does not decide placement, load, protection, or conflicts.
- SwiftData entities are converted to immutable snapshots before domain calculation.
- `MiraClock` makes the demo reproducible.
- `HybridSemanticClassifier` selects Foundation Models or deterministic fallback.
- AI never returns an action that is executed directly.

## Persistence

Current demo stores:
- app settings
- calendar items
- margin goals
- base availability rules
- adjustment sessions
- pending invitations
- explicit load rules
- important people

Future split:
- confirmed calendar events → EventKit
- Mira-specific metadata → CloudKit

## Safety and privacy

- no external backend
- no external LLM
- no analytics SDK
- no raw event titles in remote logs
- no implicit behavioral learning
- all schedule changes require user action
