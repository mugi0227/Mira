# Graph Report - Mira  (2026-08-26)

## Corpus Check
- Corpus is ~18,946 words - fits in a single context window. You may not need a graph.

## Summary
- 625 nodes · 1491 edges · 35 communities (34 shown, 1 thin omitted)
- Extraction: 85% EXTRACTED · 15% INFERRED · 0% AMBIGUOUS · INFERRED: 221 edges (avg confidence: 0.83)
- Token cost: 5,264 input · 2,290 output

## Community Hubs (Navigation)
- Buttons and Pixel Cat
- Event Load Scoring
- Architecture and Specifications
- Clock and Date Utilities
- Persistence Entities
- Legacy Calendar Import
- Shared Home Components
- Pending Invitations
- Candidate Date Layout
- Adjustment Form Styling
- Margin Goal Editing
- Scheduling Engine
- Candidate Domain Types
- Settings Screens
- Store Adjustment Flows
- Themes and Item Kinds
- Semantic AI Classification
- Margin Types and Placement
- Adjustment Lists
- Notifications and Reminders
- Monthly Planning Onboarding
- New Item Creation
- Calendar Grid
- Core Domain Models
- Protection Conflict Tests
- Impact Resolution
- Event Details
- Item Mutations
- Adjustment Details Sharing
- App Navigation Root
- Store Bootstrap Settings
- Design Tokens
- Color Rendering
- Protection Engine
- Bootstrap Script

## God Nodes (most connected - your core abstractions)
1. `MiraStore` - 76 edges
2. `MiraThemePalette` - 55 edges
3. `CalendarItemSnapshot` - 45 edges
4. `MarginKind` - 34 edges
5. `LoadClass` - 28 edges
6. `CandidateSlotSnapshot` - 27 edges
7. `MonthKey` - 26 edges
8. `MarginGoalSnapshot` - 25 edges
9. `PixelCatView` - 22 edges
10. `Calendar` - 21 edges

## Surprising Connections (you probably didn't know these)
- `Architecture Decisions (ADR)` --references--> `SwiftData`  [EXTRACTED]
  docs/architecture-decisions.md → Mira/Data/PersistenceModels.swift
- `LoadEngineTests` --calls--> `LoadEngine`  [INFERRED]
  MiraTests/LoadEngineTests.swift → Mira/Domain/LoadEngine.swift
- `.progressHeader` --references--> `MiraThemePalette`  [INFERRED]
  Mira/Features/Onboarding/OnboardingView.swift → Mira/DesignSystem/MiraTheme.swift
- `.body` --references--> `MiraThemePalette`  [INFERRED]
  Mira/Features/Settings/LegacyImportView.swift → Mira/DesignSystem/MiraTheme.swift
- `.statusHeader` --calls--> `PixelCatView`  [INFERRED]
  Mira/Features/Adjustments/AdjustmentDetailSheet.swift → Mira/DesignSystem/PixelCatView.swift

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Domain Engines** — scheduler_engine, load_engine, protection_engine, conflict_engine, assistant_engine [EXTRACTED 1.00]
- **Demo Reproducibility Components** — mira_clock, swiftdata, docs_demo_script [INFERRED 0.90]
- **Mira Theme System** — docs_design_system_master, readme, docs_architecture_decisions [EXTRACTED 1.00]

## Communities (35 total, 1 thin omitted)

### Community 0 - "Buttons and Pixel Cat"
Cohesion: 0.05
Nodes (50): ButtonStyle, Configuration, MiraPressStyle, PixelCatView, .accessibilityLabel, .body, CGFloat, String (+42 more)

### Community 1 - "Event Load Scoring"
Cohesion: 0.09
Nodes (20): Comparable, Mira, .snapshot, LoadClass, heavy, .id, light, normal (+12 more)

### Community 2 - "Architecture and Specifications"
Cohesion: 0.07
Nodes (25): App, AssistantEngine, ConflictEngine, Architecture Overview, Architecture Decisions (ADR), Demo Script, Design System Master, Implementation Status (+17 more)

### Community 3 - "Clock and Date Utilities"
Cohesion: 0.10
Nodes (18): DemoClock, .calendar, MiraClock, SystemClock, .calendar, .now, Calendar, .mira (+10 more)

### Community 4 - "Persistence Entities"
Cohesion: 0.15
Nodes (19): AdjustmentEntity, .candidates, .status, AppSettingsEntity, BaseRuleEntity, CalendarItemEntity, .snapshot, ImportantPersonEntity (+11 more)

### Community 5 - "Legacy Calendar Import"
Cohesion: 0.08
Nodes (24): ImportStep, analyzing, completed, duplicates, intro, review, source, LegacyImportCategory (+16 more)

### Community 6 - "Shared Home Components"
Cohesion: 0.11
Nodes (20): Binding, EmptyStateView, .body, ProgressPill, .body, Int, String, AgendaRow (+12 more)

### Community 7 - "Pending Invitations"
Cohesion: 0.12
Nodes (17): Data, PendingInvitationEntity, .candidates, .status, InvitationStatus, accepted, adjustment, archived (+9 more)

### Community 8 - "Candidate Date Layout"
Cohesion: 0.13
Nodes (16): CGRect, CGSize, Layout, CandidateDatePicker, .body, .cells, .columns, FlowLayout (+8 more)

### Community 9 - "Adjustment Form Styling"
Cohesion: 0.14
Nodes (16): ColorScheme, MiraThemePalette, .body, LabeledTextField, .body, NewAdjustmentSheet, .body, Set (+8 more)

### Community 10 - "Margin Goal Editing"
Cohesion: 0.13
Nodes (15): Int, GoalEditorSheet, .body, GoalRow, .body, .goalColor, MarginsView, .baseRulesCard (+7 more)

### Community 11 - "Scheduling Engine"
Cohesion: 0.20
Nodes (10): DateInterval, Bool, .snapshot, BaseAvailabilityRule, .occupiedInterval, SchedulerEngine, Bool, Double (+2 more)

### Community 12 - "Candidate Domain Types"
Cohesion: 0.16
Nodes (18): Codable, Identifiable, CandidateSlotSnapshot, .interval, CandidateStatus, confirmed, held, released (+10 more)

### Community 13 - "Settings Screens"
Cohesion: 0.18
Nodes (15): Content, View, ImportantPeopleSheet, AIStatusView, .body, CapabilityRow, .body, LoadAndBufferSettingsView (+7 more)

### Community 14 - "Store Adjustment Flows"
Cohesion: 0.17
Nodes (10): String, UUID, MiraStore, .currentAssistantMessage, .now, .selectedDayItems, Bool, ModelContainer (+2 more)

### Community 15 - "Themes and Item Kinds"
Cohesion: 0.12
Nodes (13): CaseIterable, AppThemeKind, .displayName, .id, pixelCat, softMinimal, CalendarItemKind, birthday (+5 more)

### Community 16 - "Semantic AI Classification"
Cohesion: 0.22
Nodes (13): FoundationModels, EventSemanticClassifying, FoundationModelSemanticClassifier, .isAvailable, GeneratedEventClassification, HybridSemanticClassifier, .availabilityDescription, RuleBasedSemanticClassifier (+5 more)

### Community 17 - "Margin Types and Placement"
Cohesion: 0.13
Nodes (14): .snapshot, MarginKind, custom, .defaultDurationHours, .defaultPriority, freeEvening, .id, importantPeople (+6 more)

### Community 18 - "Adjustment Lists"
Cohesion: 0.18
Nodes (13): AdjustmentRow, .body, .contactSuffix, AdjustmentSegment, adjustments, .id, pending, .title (+5 more)

### Community 19 - "Notifications and Reminders"
Cohesion: 0.19
Nodes (6): .body, NotificationService, Bool, String, UUID, UserNotifications

### Community 20 - "Monthly Planning Onboarding"
Cohesion: 0.23
Nodes (8): .currentMonthGoals, Int, MonthKey, .firstDay, .interval, .monthHeader, .futureMonthCard, .monthPicker

### Community 21 - "New Item Creation"
Cohesion: 0.17
Nodes (11): NewItemMode, event, .id, margin, .symbol, .title, NewItemSheet, .canSave (+3 more)

### Community 22 - "Calendar Grid"
Cohesion: 0.22
Nodes (10): CalendarMicroBar, .symbol, MonthCalendarGrid, .body, .cells, .columns, GridItem, String (+2 more)

### Community 23 - "Core Domain Models"
Cohesion: 0.52
Nodes (11): Hashable, AssistantMessage, CalendarItemSnapshot, EventSemanticClassification, LoadEvaluation, MarginPlacementProposal, ScheduleImpact, Double (+3 more)

### Community 24 - "Protection Conflict Tests"
Cohesion: 0.23
Nodes (6): ConflictEngine, String, ProtectionConflictTests, Int, String, TestFixtures

### Community 25 - "Impact Resolution"
Cohesion: 0.24
Nodes (5): ImpactResolution, exception, relocate, String, .body

### Community 26 - "Event Details"
Cohesion: 0.22
Nodes (9): DetailRow, .body, EventDetailSheet, .deleteButton, .detailCard, .marginCard, .symbol, .timeText (+1 more)

### Community 27 - "Item Mutations"
Cohesion: 0.24
Nodes (5): UUID, Bool, UUID, .body, .loadCard

### Community 28 - "Adjustment Details Sharing"
Cohesion: 0.24
Nodes (8): AdjustmentDetailSheet, .cancelButton, .candidateSection, .sharingCard, .statusHeader, .statusText, String, UIKit

### Community 29 - "App Navigation Root"
Cohesion: 0.25
Nodes (5): AppRootView, .body, .body, MainTabView, SwiftUI

### Community 30 - "Store Bootstrap Settings"
Cohesion: 0.25
Nodes (4): Int, String, UUID, .body

### Community 31 - "Design Tokens"
Cohesion: 0.36
Nodes (6): MiraCardModifier, MiraMotion, MiraRadius, MiraSpacing, CGFloat, ViewModifier

### Community 32 - "Color Rendering"
Cohesion: 0.25
Nodes (6): Color, Double, .header, .body, .body, UInt32

### Community 33 - "Protection Engine"
Cohesion: 0.29
Nodes (6): ProtectionLevel, caution, finalDefense, flexible, strong, ProtectionEngine

## Knowledge Gaps
- **150 isolated node(s):** `Observation`, `relocate`, `exception`, `.now`, `.selectedDayItems` (+145 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **1 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `MiraStore` connect `Store Adjustment Flows` to `Event Load Scoring`, `Architecture and Specifications`, `Clock and Date Utilities`, `Persistence Entities`, `Protection Engine`, `Pending Invitations`, `Margin Goal Editing`, `Scheduling Engine`, `Candidate Domain Types`, `Themes and Item Kinds`, `Semantic AI Classification`, `Margin Types and Placement`, `Notifications and Reminders`, `Monthly Planning Onboarding`, `Core Domain Models`, `Impact Resolution`, `Item Mutations`, `Store Bootstrap Settings`?**
  _High betweenness centrality (0.198) - this node is a cross-community bridge._
- **Why does `Date` connect `Clock and Date Utilities` to `Event Load Scoring`, `Persistence Entities`, `Pending Invitations`, `Candidate Date Layout`, `Adjustment Form Styling`, `Margin Goal Editing`, `Scheduling Engine`, `Candidate Domain Types`, `Store Adjustment Flows`, `Themes and Item Kinds`, `Semantic AI Classification`, `Margin Types and Placement`, `Notifications and Reminders`, `Monthly Planning Onboarding`, `New Item Creation`, `Calendar Grid`, `Core Domain Models`, `Impact Resolution`, `Item Mutations`, `Protection Engine`?**
  _High betweenness centrality (0.169) - this node is a cross-community bridge._
- **Why does `MiraThemePalette` connect `Adjustment Form Styling` to `Color Rendering`, `Buttons and Pixel Cat`, `Shared Home Components`, `Pending Invitations`, `Candidate Date Layout`, `Margin Goal Editing`, `Settings Screens`, `Adjustment Lists`, `New Item Creation`, `Calendar Grid`, `Event Details`, `Adjustment Details Sharing`, `App Navigation Root`, `Design Tokens`?**
  _High betweenness centrality (0.121) - this node is a cross-community bridge._
- **Are the 8 inferred relationships involving `MiraStore` (e.g. with `LoadEngine` and `AssistantEngine`) actually correct?**
  _`MiraStore` has 8 INFERRED edges - model-reasoned connections that need verification._
- **Are the 10 inferred relationships involving `MiraThemePalette` (e.g. with `.body` and `.body()`) actually correct?**
  _`MiraThemePalette` has 10 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Observation`, `relocate`, `exception` to the rest of the system?**
  _150 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Buttons and Pixel Cat` be split into smaller, more focused modules?**
  _Cohesion score 0.05200501253132832 - nodes in this community are weakly interconnected._