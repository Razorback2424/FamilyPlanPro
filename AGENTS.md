# AGENTS.md
Family Plan Pro — Operating Guide for Coding Agents

Goal
Keep agents fast, safe, and stage-compliant. This file tells you what to read, how to run, what to change, and when to stop.

Read this first (in this order)
1) README.md → repo purpose, local run, staged delivery overview
2) STAGED_DELIVERY.md → active stage, acceptance criteria, gates
3) VISION.md → product scope and non-goals
4) ARCHITECTURE.md → module boundaries, services, flags, perf/accessibility budgets
5) DATA_MODEL.md → entities, fields, invariants, migrations
6) STATE_MACHINES.md → transitions, guards, side-effects, telemetry

Grounding sequence (do this before any work)
- Build a short Grounding Map: list 5–10 binding constraints per doc with file → section.
- Detect the active stage = first unchecked stage in STAGED_DELIVERY.md.
- Extract that stage’s acceptance criteria verbatim (condensed) and the feature flags required.
- Refuse out-of-stage changes; cite STAGED_DELIVERY.md.

Definition of Done (every change)
- Satisfies one acceptance criterion of the active stage.
- Behind the correct feature flag(s); safe default in release.
- Tests added/updated (unit + UI smoke) and passing.
- Performance budgets met (cold start ≤1s; Current Week render ≤200ms).
- Accessibility passes (labels, Dynamic Type, contrast AA).
- Docs updated in the same PR (CHANGELOG + any affected spec).
- Demo script recorded that exercises the criterion in order.

What not to do (non-goals & safety rails)
- No finance suite, grocery-provider integrations, or deep PM features in v1.
- No calendar writes without explicit consent; export-only until the stage allows.
- No analytics content logging; counts/durations only, opt-in default off.
- No broad refactors; prefer minimal diffs that satisfy tests and gates.

Project layout (source of truth)
- App/  entry & navigation, feature flags
- Features/  Meals, Chores, Events, Rituals, Quarterly
- Services/  Persistence, Notifications, Calendar, Analytics, System
- Data/  SwiftData models, migrations, seeders
- Shared/  UI building blocks, design tokens
- Tests/  Unit, UI, performance
- docs/  vision/specs/quality
- codex/  skills, automations, team config (if present)

Setup & common commands (adjust scheme/targets if needed)
- Build (debug):  
  `xcodebuild -scheme FamilyPlanPro -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' build`
- Unit tests:  
  `xcodebuild -scheme FamilyPlanPro -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' test`
- UI tests (if separate scheme):  
  `xcodebuild -scheme FamilyPlanProUITests -destination 'platform=iOS Simulator,name=iPhone 16' test`
- Clean & reset demo data: provide an in-app Reset Demo; do not script destructive wipes.

Stage workflow (must follow)
1) Plan only: produce a Gap Matrix (criterion → current evidence → delta → tests).
2) Minimal diffs: implement one criterion at a time behind flags.
3) Tests: run unit/UI after each diff; attach artifacts.
4) Docs: tick the stage checklist and update CHANGELOG.
5) Demo: record a 2–3 minute video that follows the acceptance criteria order.

Feature flags to know (examples; see docs for the full list)
- Meals: `ff.meals.ownershipRules`, `ff.meals.groceryList`, `ff.meals.budgetStatus`
- Notifications: `ff.notifications.groceryCadence`, `ff.notifications.chores`, `ff.rituals.dailyPreview`
- Events/Calendar: `ff.events.core`, `ff.events.dateNightRotation`, `ff.calendar.hub`, `ff.projects.steps`
- Rituals: `ff.rituals.weeklyConnection`, `ff.rituals.hardTopics`
- Quarterly: `ff.quarterly.review`, `ff.quarterly.insights`
- Sync: `ff.sync.sharing`, `ff.notifications.push`

Parallel work & worktrees
- Use separate worktrees/branches per track to avoid conflicts (e.g., Stage1-Ownership, Stage1-Grocery).
- Zero file overlap between tracks. If unavoidable, define a merge protocol in the PR description.
- Human reviewer must approve diffs from each worktree before integration.

Skills & automations (optional, if present under codex/)
- skills/TEST_RUNNER → runs unit/UI/perf suites and attaches artifacts
- skills/RELEASE_BRIEFS → drafts PR notes from CHANGELOG and merged diffs
- skills/CALENDAR_SYNC → export-only operations; never write without consent
- automations/CI_FAILURE_DIGEST → summarizes failing tests; never auto-push fixes
Invoke skills by name when relevant; otherwise keep runs lean.

Ask policy (ambiguity handling)
- If a requirement is missing or contradictory, ask exactly one clarifying question with a proposed minimal patch to the docs (unified diff snippet), then wait.

Refusal policy
- If a request violates stage, safety, privacy, or non-goals, refuse and cite the source file/section. Offer the closest in-stage alternative.

PR checklist (attach in every PR)
- Demo video covering acceptance criteria in order
- Test results (unit/UI), perf logs, accessibility screenshots
- Migration notes (if schema changed)
- CHANGELOG entry + any spec updates
- Requirements Traceability Matrix: criterion → code diffs → tests

Personality & style
- `/personality terse` unless writing user-facing copy; then be warm and brief.
- Keep diffs minimal and well-commented; avoid sweeping reorganizations.

Begin every run by producing the Grounding Map, the Active Stage Gate, and a short plan. Refuse to proceed without them.

Why this file: Codex prioritizes AGENTS.md as the project’s “rules of the road” and merges it with Skills and Team Config. The desktop app’s parallel threads and worktrees are first-class, so encoding stage gates, flags, test/PR artifacts, and refusal policy here makes agent output reliably doc-grounded and reviewable.
