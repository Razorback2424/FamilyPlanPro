# ARCHITECTURE.md
Family Plan Pro — System Architecture (v1.0)

This document describes how the app is structured so engineering, QA, and Codex agents can build and test features consistently. It defines module boundaries, core services, and cross-cutting constraints that apply to every feature.

---

## Architectural goals
- Small, composable features with clear ownership per domain (Meals, Chores, Events, Rituals).
- One “composition root” to wire dependencies and feature flags.
- Local-first, offline-safe behavior with explicit, opt-in sharing later.
- Deterministic state and data migrations; predictable performance and accessibility.

---

## High-level layout

App layers (top → bottom)
- Presentation: SwiftUI screens and reusable UI components.
- Feature logic: ViewModels (MVVM), use cases, and state machines per domain.
- Services: Notification scheduling, calendar sink, analytics, clock, UUID factory, logging.
- Persistence: SwiftData models, repositories, and migrations.
- Integration: CloudKit (Stage 6), EventKit (export/write), UNUserNotificationCenter.

Repository folders
- App/ — App entry, composition root, navigation, feature flags.
- Shared/ — Design tokens, typography, icons, generic UI building blocks.
- Features/
  - Meals/
  - Chores/
  - Events/
  - Rituals/ (Weekly Connection, Daily Preview, Hard Topics)
  - Quarterly/
- Services/
  - Persistence/
  - Notifications/
  - Calendar/
  - Analytics/
  - Logging/
  - System/ (Clock, UUID, Locale/TimeZone helpers)
- Tests/ — Unit and UI tests aligned to the same folder structure.
- docs/, codex/ — Documentation and Codex configuration.

---

## Module boundaries and contracts

Each feature exposes a minimal surface:
- Screen builders (factory methods that inject dependencies).
- ViewModels (input events, published state, side-effect outputs).
- Use cases (pure or side-effecting operations with stable contracts).
- Repositories (feature-scoped data access returning domain models).

Core service interfaces (protocols)
- `Clock`: now(), today(in:), startOfWeek(in:), quarter(for:).
- `UUIDFactory`: new() for stable ID creation.
- `Logger`: info/debug/warn/error with category and metadata.
- `AnalyticsClient`: track(event: name, props: [String:RedactedValue]).
- `NotificationScheduler`: requestAuthorization(), schedule(id:, at:, type:), cancel(ids:).
- `CalendarSink`: export(items:), write(items:) [feature-flagged], revoke().
- `Persistence`: fetch/query/save/delete; transactions; migration APIs.
- `FeatureFlags`: typed accessors with defaults and remote/local overrides.

All feature code depends on protocols, not concrete implementations. The composition root binds concrete services for the running environment (debug, release, UI tests).

---

## State management

Pattern
- MVVM with single-source ViewModel state per screen.
- State machines for important flows:
  - WeeklyPlan lifecycle: Suggestion → Review → Finalized (reversible until finalize).
  - Weekly Connection wizard steps and completion.
  - Hard Topic soft-schedule: planned → snoozed → discussed → archived.

Rules
- All side effects are triggered by explicit intents on the ViewModel.
- No business logic in SwiftUI views.
- Inputs are value types; outputs update a single `@Published` state struct.

---

## Data persistence

Store
- SwiftData as the local store; CloudKit sync introduced at Stage 6.
- Entities follow the conceptual model in `DATA_MODEL.md`.

Repository pattern
- Feature repositories expose domain models, not raw SwiftData objects.
- Write paths are transactional; reads are query helpers with pagination where useful.

IDs and timestamps
- UUIDs generated via `UUIDFactory`.
- All persisted records include `createdAt`, `updatedAt`, and optional `deletedAt`.
- Audit metadata introduced when sharing is enabled: `lastModifiedBy`, `syncVersion`.

Migrations
- Every schema change increments a migration version.
- Migrations are non-destructive, additive first; destructive changes require a safe fallback.
- A migration log is captured in the Logger for troubleshooting.

---

## Navigation

Coordinator responsibilities
- Compose screens with dependencies and feature flags.
- Enforce single WeeklyPlan per week and ensure creation at entry.
- Provide deep links to domain sections (Meals, Chores, Events, Rituals, Quarterly).

Back stack rules
- Wizard-like flows (Weekly Connection) manage their own internal step stack.
- Destructive actions must present an in-flow undo or confirmation.

---

## Feature flags

Flag classes (examples)
- Meals: `ff.meals.ownershipRules`, `ff.meals.groceryList`, `ff.meals.budgetStatus`.
- Notifications: `ff.notifications.groceryCadence`, `ff.notifications.chores`, `ff.rituals.dailyPreview`.
- Events: `ff.events.core`, `ff.events.dateNightRotation`, `ff.calendar.hub`, `ff.projects.steps`.
- Rituals: `ff.rituals.weeklyConnection`, `ff.rituals.hardTopics`.
- Quarterly: `ff.quarterly.review`, `ff.quarterly.insights`.
- Sync: `ff.sync.sharing`, `ff.notifications.push`.

Behavior
- Flags default to the Stage’s target set in release builds.
- Debug builds allow in-app toggles via a hidden Developer menu.
- Disabling a flag must hide UI affordances and degrade safely without data loss.

---

## Notifications

Tenets
- Opt-in, respectful defaults, never duplicate nudges.
- Daily Preview consolidates reminders where possible.

Scheduler
- Local notifications only until push is introduced in Stage 6.
- Idempotent scheduling via deterministic IDs per cadence (e.g., `grocery-sun-<weekID>`).

Time windows
- Grocery: Sunday and Thursday at user-configurable times if a GroceryList exists.
- Daily Preview: evening window (default 7–8pm) if tomorrow has items.
- Chores: due-day morning by default.

---

## Calendar integration

Abstraction
- `CalendarSink` supports two operations:
  - `export(items:)` generates EventKit/ICS entries via share sheet (Stage 2–3).
  - `write(items:)` creates/modifies entries in user calendars (later stage, consent-gated).
- Provider pattern with Apple Calendar as the first implementation; Google as future provider.

Consent and revocation
- User grants calendar access explicitly; revocation is available in Settings.
- All calendar writes are traceable and reversible; we store local pointers to external IDs.

---

## Analytics (privacy-preserving)

Principles
- Counts and durations only; never user-entered content.
- Off by default, single toggle in Settings, per-device and per-family.

Events (examples)
- `meals.finalized`, `grocery.generated`, `grocery.nudge_shown`.
- `chores.created`, `chores.completed`, `chores.review_completed`.
- `events.created`, `events.exported`, `events.rotation_applied`.
- `ritual.weekly.completed`, `preview.opened`, `hardtopic.created`.
- `quarterly.completed`, `insights.viewed`.

Transport
- Batched, background-safe, and dropped when offline (no retries that block UX).

---

## Error handling and logging

Policy
- Fail soft; keep the weekly plan usable even when integrations fail.
- Present human-readable recovery messages; never leak implementation details to users.

Logger
- Category-based logging with levels; sensitive values are redacted.
- Attach error IDs to user-visible errors so support can correlate logs.

---

## Performance budgets

Hard budgets
- Cold start to Current Week ≤ 1s (release build on modern iPhones).
- Week view render ≤ 200 ms with representative data (21+ meal slots, 10 chores, 3 events).

Practices
- Avoid heavy work on main thread; precompute snapshot summaries off the main thread.
- Use on-demand fetching for historical weeks; keep only Current and Previous in memory.

---

## Accessibility and internationalization

Accessibility
- All controls labeled for VoiceOver; dynamic grouping in complex lists.
- Dynamic Type supported; minimum touch target size respected.
- Color contrast AA; state must be legible without color.

Internationalization
- Copy centralized in a Strings layer; avoid concatenation that breaks grammar.
- Dates and times formatted using Locale; respect user 12/24-hour settings.

---

## Concurrency and backgrounding

Concurrency
- Use Swift Concurrency with structured tasks; no detached tasks without ownership.
- Services enforce their own serialization where needed (e.g., Persistence transaction queue).

Backgrounding
- Save on scene transitions; schedule notifications and export tasks opportunistically.
- Do not rely on long-running background tasks for core flows.

---

## Security and privacy

Data
- Local-first; no third-party trackers. Cloud sync requires explicit opt-in.
- Sensitive artifacts (WeeklyNotes, Hard Topics) stored locally and synced only when sharing is enabled.

Permissions
- Ask only when needed, in-context, with a clear why and how to revoke.

---

## Sync (Stage 6)

Approach
- CloudKit-backed containers for Family sharing.
- Merge policy: last writer wins on primitive fields; prompt-based merge for WeeklyPlan artifacts (meals/chores/events/notes) to avoid silent data loss.

Audit trail
- `lastModified`, `lastModifiedBy`, and operation logs for conflict prompts and resolutions.

Offline behavior
- Full local functionality; on reconnect, present merge prompts if divergence exists.

---

## Testing architecture

Unit tests
- Pure business rules (ownership assignment, recurrence math, budget thresholds).
- Repository fakes; in-memory Persistence for deterministic tests.

UI tests
- Smoke tests for core rituals and stage gates.
- Accessibility assertions (labels present, actionable elements reachable).

Contract tests
- Service protocol conformance (CalendarSink, NotificationScheduler) with stub providers.

Performance tests
- Automated checks for cold start and week render budgets.

---

## Environments and configuration

Build configurations
- Debug: developer menu, flag toggles, verbose logging.
- Release: flags fixed to stage, analytics off by default.

Config sources
- Local defaults in the app bundle; developer overrides via a plist in Debug; no remote config in v1.

---

## Composition root (wiring)

Responsibilities
- Instantiate services; bind protocols to implementations.
- Initialize Persistence and run migrations.
- Read feature flags; pass environment to screen builders.
- Provide global singletons only for stateless helpers (e.g., formatters). All other dependencies are injected.

---

## Evolution and extensions

Future providers
- Calendar: Google provider behind the same `CalendarSink`.
- Notifications: push provider added as opt-in with server component.
- Sync: cross-platform strategy could reuse the same domain contracts if a second client is introduced.

Change policy
- Any change that crosses modules must update this document and relevant specs in the same PR.
- Backwards-incompatible persistence changes require a migration plan and a rollback note in `MIGRATIONS.md`.

---

End of file.
