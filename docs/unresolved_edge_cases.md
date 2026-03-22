# Unresolved Edge Cases

Grounding map
- Date: 2026-03-21
- Active stage: Stage 1 — Meals to Vision
- Binding constraints:
  - Stage 1 still requires GroceryList finalize/edit proof, budget visibility, safe feature-flag degradation, and tests/accessibility to pass.
  - `WeeklyPlan` / `MealSlot` / `GroceryList` remain the current source-of-truth models.
  - State-machine contracts require finalized side effects to stay aligned with reopen behavior and notification gating.

## Open Risks

- Date: 2026-03-21
  Severity: Low
  Area/File(s): `FamilyPlanPro/Views/GroceryListView.swift`, `STAGED_DELIVERY.md`
  Description: Verified closure. Mendel added direct UI coverage in `testFinalizedGroceryDeleteUndoRestoresDeletedItem`, Boole reported that exact delete -> Undo restore path passed, and adjacent finalized-flow navigation coverage (`testReopenFromFinalizedReturnsToSuggestions`) also passed. The grocery deletion undo issue should now be considered closed.
  Why it matters: Stage 1 needed an adequate visible in-screen recovery path plus direct proof that the finalized/grocery flow remains stable around it. That combined evidence now exists, so this issue is no longer active.
  What should be rechecked next: Regression watch only if Grocery List deletion, finalized reopen behavior, or persistence wiring changes again.

- Date: 2026-03-21
  Severity: Low
  Area/File(s): `FamilyPlanPro/Notifications/GroceryCadenceScheduler.swift`, `FamilyPlanPro/FamilyPlanProApp.swift`
  Description: Reclassified debt. The harness-consistency batch is functionally closed: `UITEST_STATUS` and debug-route launches now share the same runtime parser and notification-side-effect behavior for recognized test destinations. The remaining issue is contract clarity, not behavior.
  Why it matters: The repo still exposes multiple launch inputs and aliases, so the authoritative launch vocabulary is implicit rather than clearly declared. That can still create maintenance confusion, but it is no longer a live functional mismatch.
  What should be rechecked next: Treat this as documentation/callsite cleanup only. Prefer one canonical launch input in docs/tests over time, or explicitly document `UITEST_STATUS` as a compatibility alias to the debug-route mapping.

- Date: 2026-03-21
  Area/File(s): `FamilyPlanPro/Views/FinalizedView.swift`, `FamilyPlanPro/Notifications/GroceryCadenceScheduler.swift`
  Severity: Low
  Description: Verified closure. `FinalizedView.cadenceStatusText` now says “You’ll get grocery reminders on the remaining reminder days this week,” which no longer overstates the scheduler’s actual remaining-day behavior.
  Why it matters: The prior source-of-truth mismatch between finalized-week copy and the cadence scheduler is resolved by the narrower wording.
  What should be rechecked next: Regression watch only if cadence wording or reminder-day logic changes again.

- Date: 2026-03-21
  Severity: Low
  Area/File(s): `FamilyPlanPro/Views/GroceryListView.swift`, `FamilyPlanPro/Views/FinalizedView.swift`
  Description: Residual regression watch only. Grocery delete -> Undo is now proven in-session, but there is still no explicit automated proof that a restored item survives a leave/reopen boundary.
  Why it matters: This is no longer a Stage 1 blocker, but it remains a smaller persistence watch item around the Grocery List restore flow.
  What should be rechecked next: Add one follow-up persistence check only if this area is touched again or if a regression appears.

- Date: 2026-03-21
  Severity: Low
  Area/File(s): `FamilyPlanProUITests/FamilyPlanProUITests.swift`, `FamilyPlanPro/Views/GroceryListView.swift`
  Description: Verified closure. Boole reported a passing build and passing targeted Grocery List UI tests, so the former Grocery List smoke-path blocker is closed.
  Why it matters: The prior blocker was Stage 1 proof that finalize -> GroceryList -> add/edit item completes under XCTest. That proof now exists on the current local implementation, so this path should no longer be treated as an open release blocker.
  What should be rechecked next: Keep this path on regression watch only when `GroceryListView.swift` or the related UI test changes again; otherwise treat it as verified and closed.

- Date: 2026-03-21
  Severity: Low
  Area/File(s): `FamilyPlanPro/Views/GroceryListView.swift`
  Description: Verified closure. Manual grocery item creation now scrolls the newest item into view and exposes the newest blank row through a dedicated `grocery-item-new` accessibility identifier, and the targeted UI test has passed against that updated behavior.
  Why it matters: This closes the earlier visibility/editability gap where new items could appear off-screen or be hard to target deterministically. It should now be considered a regression-watch item rather than an active unresolved issue.
  What should be rechecked next: Revisit only if longer grocery lists or future row-layout changes reintroduce focus/visibility problems.

## State/Model Risks

- Date: 2026-03-21
  Severity: Medium
  Area/File(s): `FamilyPlanPro/Models.swift`, `docs/tech/DATA_MODEL.md`
  Description: Lead active candidate. The model/spec drift is concrete and split across true functional risk versus documentation-only drift.
  Why it matters: The current Stage 1 runtime is stable enough to use, but the canonical spec still over-describes a richer multi-tenant, audit-heavy model that the shipped SwiftData schema does not implement. That leaves some mismatches as real correctness risk and others as stale documentation.
  What should be rechecked next: Narrow `DATA_MODEL.md` to the actual Stage 1 schema or explicitly mark future-only fields/invariants. The highest-signal mismatches are:
  Functional risk:
  - Family ownership boundary is underspecified in code. The spec says all records belong to exactly one `Family` via explicit `familyId`, but several persisted models rely on weak parent pointers instead of a required family foreign key: `User.family`, `WeeklyPlan.family`, `OwnershipRulesSnap.family`, `MealSlot.plan`, `MealSuggestion.slot`, `GroceryList.plan`. That makes tenant-boundary invariants harder to prove from the schema alone.
  - WeeklyPlan identity differs materially. The spec requires a unique `(familyId, year, isoWeek)` identity and derives week dates from that, but code stores only `startDate` and has no persisted uniqueness guard. That can permit multiple plans for the same family/week unless higher-level logic prevents it.
  - MealSuggestion cardinality differs. The spec models `MealSlot 1—N MealSuggestion`, but code stores only two single relationships on `MealSlot` (`pendingSuggestion`, `finalizedSuggestion`) plus a weak back-reference on `MealSuggestion`. That changes lifecycle assumptions and is a real source-of-truth risk for replacement/conflict behavior.
  Documentation-only drift:
  - Common audit fields from the spec are absent across Stage 1 models: `createdAt`, `updatedAt`, `deletedAt`, monotonic update rules, and `lastModifiedBy` are not present in the SwiftData schema.
  - Several spec-only fields are not implemented in Stage 1 code: `Family.calendarDefaults`, `Family.featureFlags`, `UserProfile.avatarColor`, `UserProfile.isPrimary`, `UserProfile.calendarWriteConsent`, `MealSlot.label`, `MealSuggestion.notes`, `GroceryItem.qty`, `GroceryItem.section`.
  - The spec describes additional entity boundaries and future stages (`BudgetStatus` as a model concept, WeeklyNotes, Chore, Event, AuditMetadata) that are intentionally not represented in the current Stage 1 SwiftData file.

- Date: 2026-03-21
  Severity: Medium
  Area/File(s): `FamilyPlanPro/DataManager.swift`, `FamilyPlanPro/Views/WeeklyPlannerContainerView.swift`
  Description: The current-week bootstrap flow effectively treats the first fetched family as the app-wide default family.
  Why it matters: The docs frame `Family` as the tenant boundary, but the current runtime path always drives planning off `getOrCreateDefaultFamily()` and the first queried family. If multiple families can exist locally, the source of truth for “current family” is underspecified.
  What should be rechecked next: Verify whether multi-family data is intentionally unsupported in Stage 1, and if so document that constraint clearly; otherwise add a tracked risk for incorrect family selection at app entry.

## UI/Test Brittleness

- Date: 2026-03-21
  Severity: Low
  Area/File(s): `FamilyPlanProUITests/FamilyPlanProUITests.swift`, `FamilyPlanPro/FamilyPlanProApp.swift`
  Description: Reclassified debt. `UITEST_STATUS` values now flow through `DebugLaunchRoute`, and there is direct UI coverage that `UITEST_STATUS=reviewMode` and `-ui_debug_route review` land on the same screen. The remaining issue is launch-contract clarity rather than functional divergence.
  Why it matters: Future drift is still possible if docs and callsites keep mixing old status tokens and route names, but the runtime mismatch has been closed.
  What should be rechecked next: Consolidate docs/tests toward one canonical launch input over time, or explicitly keep both as supported synonyms.

- Date: 2026-03-21
  Severity: Low
  Area/File(s): `FamilyPlanPro/FamilyPlanProApp.swift`, `FamilyPlanProUITests/FamilyPlanProUITests.swift`, `scripts/ui_build_and_shoot.sh`
  Description: Reclassified debt. The runtime now has a mostly single launch-state mapping because `UITEST_STATUS` also passes through `DebugLaunchRoute`, including legacy tokens and route-style aliases. What remains is vocabulary clarity, not a broken mapping path.
  Why it matters: The repo still exposes multiple user-facing ways to describe the same state, so the authoritative vocabulary is implicit rather than clearly declared.
  What should be rechecked next: Treat any follow-up here as documentation/callsite cleanup, not core mapping logic.

- Date: 2026-03-21
  Severity: Medium
  Area/File(s): `FamilyPlanProUITests/FamilyPlanProUITests.swift`
  Description: Several UI tests still assert older user-facing strings such as `Save Suggestion`, while parts of the app have already moved to broader week-level wording.
  Why it matters: Microcopy changes are causing avoidable UI test churn, which makes it harder to distinguish genuine workflow regressions from label-only breakage.
  What should be rechecked next: Audit the remaining UI test string assertions against the latest user-facing copy and prefer narrower intent checks where possible.

## Feature Flag Gaps

- Date: 2026-03-21
  Severity: Low
  Area/File(s): `FamilyPlanPro/Views/GroceryListView.swift`, `FamilyPlanPro/FamilyPlanProApp.swift`
  Description: Grocery List editing and screenshot/test seeding currently rely on finalized-week assumptions more than explicit Stage 1 flag combinations.
  Why it matters: Stage 1 requires safe degradation when flags are toggled. The grocery UI has received several finalize-path and screenshot-path tweaks, but the current unresolved test flakiness makes it harder to prove flag-off behavior is still clean.
  What should be rechecked next: Manually re-verify grocery entry and finalized navigation with grocery-related flags disabled after the current UI smoke path is stable.

- Date: 2026-03-21
  Severity: Low
  Area/File(s): `FamilyPlanPro/Views/FinalizedView.swift`
  Description: Budget entry is gated on `plan.groceryList != nil` even when the budget-status feature is enabled, which effectively couples the budget slice to Grocery List availability rather than only to finalized-week budget state.
  Why it matters: This may be intentional for Stage 1, but as written it is a feature-flag/source-of-truth ambiguity: if `mealsBudgetStatus=true` and grocery-list behavior is disabled or unavailable, the budget UI is present but nonfunctional.
  What should be rechecked next: Confirm whether budget status is intentionally dependent on Grocery List creation for Stage 1; if not, the finalized budget affordance should be decoupled or hidden when that prerequisite is absent.

## Questions To Re-check

- Date: 2026-03-21
  Severity: Low
  Area/File(s): `docs/tech/ARCHITECTURE.md`, current app implementation
  Description: The architecture doc describes repository/service abstractions and MVVM boundaries that the current app does not consistently follow.
  Why it matters: This is not an immediate Stage 1 blocker, but it creates “source of truth” ambiguity when evaluating whether current behavior is correct versus merely pragmatic.
  What should be rechecked next: Decide whether the docs should be narrowed to match the current SwiftUI + DataManager implementation until later stages justify the fuller architecture.

- Date: 2026-03-21
  Severity: Low
  Area/File(s): `README.md`, current repository structure
  Description: The README’s repository layout and architecture guidance no longer match the actual source tree.
  Why it matters: The README still points to `App/`, `Data/`, `Services/`, and `Tests/` style folders, while the live repo centers on `FamilyPlanPro/`, `FamilyPlanProTests/`, and `FamilyPlanProUITests/`. That mismatch increases onboarding and review friction.
  What should be rechecked next: Update the README’s structure/source-of-truth sections when the next non-trivial repo maintenance change is made.
