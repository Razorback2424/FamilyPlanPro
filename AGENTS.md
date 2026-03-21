# AGENTS.md
Family Plan Pro — Working Guide for Coding Agents

## Mission
Build the smallest useful version of Family Plan Pro quickly, while staying aligned with the repo's staged delivery plan.

Optimize for:
- a working local-first SwiftUI + SwiftData app
- visible progress in small vertical slices
- clarity, speed, and correctness over polish
- a usable demo over completeness
- minimal diffs that match the current stage

## Read First
Read these before making changes:
1. `README.md`
2. `STAGED_DELIVERY.md`
3. `VISION.md`
4. `docs/tech/ARCHITECTURE.md`
5. `docs/tech/DATA_MODEL.md`
6. `docs/tech/STATE_MACHINES.md`

## Grounding Sequence
Before substantial work:
1. Build a short Grounding Map with binding constraints from the docs above.
2. Detect the active stage as the first unchecked stage in `STAGED_DELIVERY.md`.
3. Extract that stage's acceptance criteria and feature flags.
4. Refuse or defer requests that are clearly out of stage unless the user explicitly asks for that tradeoff.

## Product Intent
The app is a calm weekly coordination tool for a household.

Right now, the codebase is centered on a weekly meal-planning loop:
- one current-week `WeeklyPlan`
- date-based `MealSlot`s
- suggestion, review, conflict, and finalized states
- optional Stage 1 additions behind feature flags

Do not treat this repo like a generic family organizer. Work from the current product slice already implemented here.

## Current Scope
The existing app structure supports:
- creating or bootstrapping a family and current week
- entering meal suggestions
- submitting for review
- accepting or rejecting suggestions
- conflict handling
- finalized weekly meal summary
- Stage 1 flags for ownership rules, grocery list, grocery cadence, and budget status

Prefer extending or hardening these flows over inventing unrelated new domains.

## Explicitly Out of Scope Unless Requested
Do not add these by default:
- cloud sync or collaboration
- authentication or accounts
- external calendar providers
- Apple Notes or Google integrations
- AI suggestions
- advanced theming/polish work
- large architectural refactors
- speculative abstractions for future domains

When in doubt, cut scope.

## Architecture Rules
Match the codebase that exists today.

Current implementation is centered in:
- `FamilyPlanPro/Models.swift`
- `FamilyPlanPro/DataManager.swift`
- `FamilyPlanPro/Views/`
- `FamilyPlanPro/Notifications/`
- `FamilyPlanProTests/`
- `FamilyPlanProUITests/`

Prefer:
- SwiftUI views with straightforward state ownership
- SwiftData models and direct CRUD
- `DataManager` for the workflow and persistence logic already living there
- `@Query` and `modelContext` where they keep things simple
- feature-flagged changes for staged work

Avoid adding unless clearly required:
- repository layers
- protocol-heavy service splits
- generic base views/view models
- dependency injection frameworks
- coordinator patterns

## Data Model Rules
Work with the current persisted model surface unless the task requires a schema change:
- `Family`
- `User`
- `WeeklyPlan`
- `OwnershipRulesSnap`
- `MealSlot`
- `MealSuggestion`
- `GroceryList`
- `GroceryItem`

Do not collapse the current model into a generic MVP schema like `PlanItem` unless the user explicitly asks for a redesign.

Keep schema changes small, stage-aligned, and migration-conscious.

## Slice-First Policy
Always implement in small vertical slices.

A good slice:
- produces visible user value
- fits one acceptance criterion or one bug fix
- is testable or at least directly verifiable
- does not require reworking the whole app first

Prefer slices like:
- fix a broken navigation or workflow transition
- harden grocery-list generation for finalized weeks
- repair a feature-flag fallback path
- add targeted unit/UI coverage for an existing state-machine edge case

Avoid horizontal plans like:
- redesign all models first
- rewrite all views first
- broad cleanup without user value

## Planning Policy
If a task is ambiguous, risky, or larger than one slice:
1. identify the smallest acceptable scope
2. state what is intentionally deferred
3. implement only the next slice

If the task is obviously larger than the active stage, say so and narrow it.

## Subagent Policy
Use subagents only when they reduce uncertainty for a bounded task.

Good uses:
- codebase exploration
- doc/spec comparison
- finding regressions or test gaps
- bounded review after implementation

Avoid:
- overlapping writes to the same files
- parallel architecture invention
- multiple agents coding the same slice

Default rule:
- many agents may analyze
- one agent owns the actual code slice

## Definition Of Done
A slice is done when:
- it satisfies the intended bug fix or acceptance criterion
- it compiles, or is as close to compile-ready as possible
- persistence behavior is correct if data is touched
- relevant tests are added or updated when practical
- feature-flag behavior remains safe
- scope stayed narrow
- intentional deferrals are stated clearly
- no unnecessary abstractions were introduced

## Build And Verification
Before concluding work:
- review changed files for accidental complexity
- verify the user-facing flow
- check for obvious SwiftUI and SwiftData mistakes
- note blockers, assumptions, or follow-up work

When practical, run the relevant command:
- Build: `xcodebuild -scheme FamilyPlanPro -configuration Debug -destination 'generic/platform=iOS Simulator' build`
- Tests: `xcodebuild -scheme FamilyPlanPro -configuration Debug -destination 'generic/platform=iOS Simulator' test`

If a build or test run cannot be completed, say so explicitly.

## Output Expectations
When finishing a task, report:
1. what changed
2. what user-visible behavior now works
3. what was intentionally deferred
4. any blockers or risks
5. the next recommended slice

Keep summaries concrete and brief.

## Decision Rules
When multiple approaches are possible, prefer the one that:
- has the smallest implementation cost
- has the lowest schema and migration risk
- preserves the current staged architecture
- reaches a working demo fastest
- is easiest to revise tomorrow

Do not optimize for elegance over shippability.

## Style
- Keep diffs minimal.
- Preserve the current product vocabulary and flow.
- Prefer strengthening the current meal-planning workflow over introducing new surface area.
- Be terse in engineering communication unless writing user-facing copy.
