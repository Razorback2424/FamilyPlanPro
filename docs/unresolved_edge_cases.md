# Unresolved Edge Cases

Grounding map
- Date: 2026-03-21
- Active stage: Stage 1 — Meals to Vision
- Binding constraints:
  - Stage 1 still requires GroceryList finalize/edit proof, budget visibility, safe feature-flag degradation, and tests/accessibility to pass.
  - `WeeklyPlan` / `MealSlot` / `GroceryList` remain the current source-of-truth models.
  - State-machine contracts require finalized side effects to stay aligned with reopen behavior and notification gating.

## Open Risks

- Date: 2026-03-22
  Severity: Low
  Area/File(s): `FamilyPlanPro/Views/SuggestionView.swift`, `FamilyPlanPro/Views/MealSlotEntryView.swift`
  Description: Verdict: fixed. The planner readability issue is addressed by moving Suggestions to a compact disclosure-row pattern while keeping saved state visible in the collapsed summary label.
  Why it matters: The landed `SuggestionView` delta keeps the important state readable at a glance: day/meal, date, saved suggestion text, and responsible/default-owner context are all visible before expansion. The edit controls remain in the same row source of truth rather than being pushed into a separate screen or modal flow.
  What should be rechecked next: Regression watch only if future row compaction starts hiding the saved suggestion or owner context again.

- Date: 2026-03-22
  Severity: Medium
  Area/File(s): `FamilyPlanPro/Views/SuggestionView.swift`, `FamilyPlanPro/Views/FamilySettingsView.swift`, `FamilyPlanPro/DataManager.swift`
  Description: Verdict: partially fixed. The ownership-rule controls did not disappear; they moved out of Planner into Settings as a dedicated `Current week defaults` section, and Planner now leaves a lightweight pointer behind. The remaining risk is conceptual split between current-week defaults in `SettingsView` and family-wide defaults still living in `FamilySettingsView`.
  Why it matters: The good news is the feature remains discoverable: the UI test now verifies the planner no longer shows `Ownership Rules`, Settings exposes weekday controls, and Planner explicitly says defaults are edited in Settings. The unresolved behavior/UX risk is that users now have two default-owner surfaces with different scopes, and the distinction between “current week defaults” and “new week family defaults” may still be easy to miss.
  What should be rechecked next: Treat relocation as safe but not fully closed. A small follow-up should make the scope difference between `Settings` and `Family Settings` more explicit so users do not confuse week-local ownership changes with household defaults for future weeks.

- Date: 2026-03-22
  Severity: Low
  Area/File(s): `FamilyPlanPro/Views/SuggestionView.swift`, `FamilyPlanPro/Views/FamilySettingsView.swift`
  Description: Partially resolved. Planner now leaves behind a lightweight pointer that weekday defaults are edited in Settings, which closes the original discoverability gap.
  Why it matters: This is now a lower residual watch item rather than the main relocation risk. The feature did not disappear from the user’s point of view.
  What should be rechecked next: Revisit only if later UX testing shows users still cannot find the moved controls.

- Date: 2026-03-22
  Severity: Low
  Area/File(s): `FamilyPlanPro/Views/WeeklyPlannerContainerView.swift`
  Description: Verified closure. The oversized-header issue appears fixed in code: the `This Week` control has been removed from the top `.safeAreaInset` band and moved into existing toolbar/navigation-bar chrome.
  Why it matters: This removes the duplicate top header strip that was the most likely source of oversized planner chrome in screenshots. The fix follows the narrowest safe path because it reuses existing nav chrome instead of changing each planner state’s content layout.
  What should be rechecked next: Regression watch only if planner screenshots still show abnormal top spacing after this toolbar move.

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

- Date: 2026-03-22
  Severity: Low
  Area/File(s): `FamilyPlanPro/Views/WeeklyPlannerContainerView.swift`, child planner views
  Description: Adjacent UI risk: the planner flow now mixes container-level navigation chrome (`Weekly Planner`) with child-level titles plus a persistent top inset action, which increases the chance of title competition and cramped top spacing across different planner states.
  Why it matters: Even though the top inset is gone, the planner shell can still carry both container-level title chrome (`Weekly Planner`) and child-level titles in different states. That is now a smaller adjacent watch item rather than the main screenshot root cause.
  What should be rechecked next: Only revisit if screenshots still show title competition or inconsistent top spacing after the toolbar change.

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

- Date: 2026-03-22
  Severity: High
  Area/File(s): `FamilyPlanPro/FamilyPlanProApp.swift`
  Description: Main persistence risk in the current store-open fallback: if `ModelContainer` creation fails, the app unconditionally deletes the on-disk SQLite store and retries.
  Why it matters: This turns any schema mismatch, migration bug, or transient open failure into silent local data loss. It is especially risky because the fallback runs at app bootstrap, before the user has any chance to understand or recover what was lost.
  What should be rechecked next: The narrowest safer behavior change is to stop auto-deleting the store on first open failure. Fail closed instead: surface/log the container error and preserve the store for diagnosis or explicit recovery. Any destructive reset should be a deliberate, separately-invoked path rather than the default retry behavior.

- Date: 2026-03-22
  Severity: Medium
  Area/File(s): `FamilyPlanPro/Models.swift`, `FamilyPlanPro/FamilyPlanProApp.swift`
  Description: Verdict: partially fixed. The specific `defaultOwnershipRulesJSON` migration hazard is addressed in code: the stored field is now optional and `defaultOwnershipRules` cleanly falls back to `[:]` when legacy rows have `nil`, and `PersistenceTests` now includes coverage for that legacy-missing case.
  Why it matters: This closes the narrow root cause behind warnings triggered by a newly mandatory `defaultOwnershipRulesJSON` field. However, the surrounding persistence risk is not fully gone because `FamilyPlanProApp` still deletes the store if `ModelContainer` creation fails, so other migration/schema problems could still turn into silent local data loss.
  What should be rechecked next: Treat the `defaultOwnershipRulesJSON` issue itself as fixed unless a new warning shows otherwise. Keep review attention on the broader store-open failure path and on other mandatory fields that may still be migration-sensitive.

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

- Date: 2026-03-22
  Severity: Medium
  Area/File(s): `FamilyPlanPro/Models.swift`
  Description: Adjacent persistence hazard: several other Stage 1 stored properties are also non-optional and migration-sensitive if introduced after the original schema, including `OwnershipRulesSnap.rulesJSON`, `OwnershipRulesSnap.fridaySimple`, `WeeklyPlan.budgetTargetCents`, and `WeeklyPlan.budgetStatus`.
  Why it matters: `defaultOwnershipRulesJSON` is the clearest warning trigger, but it is not unique. The repo currently depends on required stored attributes without a visible migration layer, so any later-added mandatory field can create the same store-open risk on older installs.
  What should be rechecked next: When investigating migration warnings, audit the change history of every non-optional stored property added after the first shipped schema, not just `defaultOwnershipRulesJSON`. The smallest safe follow-up is a list of mandatory attributes that require backfill assumptions.

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
  Severity: High
  Area/File(s): `FamilyPlanPro/Models.swift`, `FamilyPlanPro/Views/WeeklyPlannerContainerView.swift`, clarified MVP path
  Description: Clarified-MVP integration risk. Adding a generic `PlanItem` layer on top of the existing meal-specific workflow creates a dual-source-of-truth hazard unless the repo explicitly decides whether meals remain separate or are mirrored into generic weekly items.
  Why it matters: The current app already has a working weekly meal state machine centered on `WeeklyPlan -> MealSlot -> MealSuggestion -> GroceryList`. Introducing `PlanItem` without a strict ownership rule can create duplicate representations of the same week commitments, conflicting completion/status semantics, and ambiguous routing between the existing planner and a new “This Week” surface.
  What should be rechecked next: Before any coding, define one explicit rule: either `PlanItem` excludes meals in the first MVP cut, or meals are represented there through a one-way derived projection. Avoid allowing both `MealSlot` and `PlanItem` to become first-class editable sources for the same meal.

- Date: 2026-03-21
  Severity: High
  Area/File(s): `FamilyPlanPro/Models.swift`, `docs/tech/DATA_MODEL.md`, clarified MVP path
  Description: Clarified-MVP persistence risk. A new generic `PlanItem` model plus `WeeklyCheckIn` can amplify the existing weak relationship layer unless the new models introduce clearer family/week ownership than the current meal schema does.
  Why it matters: The repo already has active model/spec drift around explicit family identity and week identity. Adding two new persisted layers without stronger ownership fields or at least a clearly documented parent chain risks deepening ambiguity around which records belong to which family/week and how they should be fetched, migrated, and deleted.
  What should be rechecked next: When the new models land, verify they choose one consistent ownership scheme up front: explicit `weeklyPlan`/week anchor, explicit family anchor, and unambiguous cascade behavior. Do not repeat the current “weak reference plus implicit parent” ambiguity if avoidable.

- Date: 2026-03-21
  Severity: Medium
  Area/File(s): `FamilyPlanPro/Views/WeeklyPlannerContainerView.swift`, new `This Week` screen, clarified MVP path
  Description: Navigation/state-machine collision risk. A new “This Week” screen with quick add/edit/status can easily compete with the existing meal-state-machine entrypoint if both claim to be the weekly home screen.
  Why it matters: The current planner shell routes users through meal workflow states. If “This Week” becomes a parallel weekly hub without a clear relationship to the current planner, the app can feel like it has two week homes with different mental models and overlapping edit affordances.
  What should be rechecked next: For the first read-only slice, this can safely ignore deep workflow unification and generic editing. What it must explicitly avoid is presenting itself as a replacement planner home or offering actions that imply it can drive the meal workflow. Keep it clearly additive: a summary surface or child view that links outward rather than competing with the existing planner router.

- Date: 2026-03-21
  Severity: Medium
  Area/File(s): `FamilyPlanPro/Views/WeeklyPlannerContainerView.swift`, `FamilyPlanPro/Views/SuggestionView.swift`, `FamilyPlanPro/Views/FinalizedView.swift`
  Description: Biggest UI confusion risk for a read-only `This Week` slice: inside the current shell, users are trained that the planner surface always reflects one meal-workflow state (`Suggestions`, `Review`, `Conflict`, `Finalized`). A `This Week` screen added there can be misread as another planner state rather than as a neutral cross-week summary.
  Why it matters: That confusion is stronger than any single row-level affordance problem because the current container already behaves like a workflow router. If `This Week` appears in the same position without a clearly different framing, users can infer it replaces or supersedes the meal planner state rather than summarizing it.
  What should be rechecked next: If this slice lands inside the existing shell, give it unmistakably summary-oriented framing and outward navigation. It should read like “This Week overview” with links into the planner, not like a new peer state beside `Suggestions` or `Finalized`.

- Date: 2026-03-21
  Severity: Low
  Area/File(s): `FamilyPlanPro/Views/WeeklyPlannerContainerView.swift`, likely read-only `This Week` slice
  Description: A lightweight navigation entry to a separate `This Week` screen would materially reduce the current confusion risk compared with inserting `This Week` inline as another container-controlled state.
  Why it matters: A separate destination preserves the existing mental model that the planner container is the meal workflow router, while making `This Week` read as an optional overview layer. That lowers the chance that users will misinterpret it as replacing `Suggestions`, `Review`, `Conflict`, or `Finalized`.
  What should be rechecked next: Prefer a clearly labeled navigation entry or adjacent surface for the first read-only slice. Only consider inline insertion if the container itself is intentionally being redesigned away from meal-state routing.

- Date: 2026-03-21
  Severity: Medium
  Area/File(s): separate `This Week` entry from `WeeklyPlannerContainerView`
  Description: Even as a separate screen, the top confusion risk is duplicate “current week” authority: users may not know whether the real weekly source of truth is the meal planner screen or `This Week` when both are accessible as peer destinations.
  Why it matters: The app would then present two places that appear to describe the same week. If the `This Week` screen is read-only while the planner is stateful and editable, users can still form the wrong expectation about where week decisions are supposed to happen.
  What should be rechecked next: Smallest mitigation: place the entry as an obvious secondary navigation action and use one short framing line at the top of `This Week` that says it is an overview. Keep row actions phrased as “Open Planner” or equivalent so ownership stays clear.

- Date: 2026-03-21
  Severity: Medium
  Area/File(s): separate `This Week` screen, `FamilyPlanPro/Views/SuggestionView.swift`, `FamilyPlanPro/Views/FinalizedView.swift`
  Description: The second biggest confusion risk is stale-summary interpretation: a read-only `This Week` overview can look like the authoritative live state even when the underlying meal planner is in a different workflow stage or requires action elsewhere.
  Why it matters: Users may read summary rows as final answers and miss that they still need to go into `Suggestions`, `Review`, or `Finalized` to act. This is especially likely if the summary uses the same meal names/status language without clearly signaling that it is an overview.
  What should be rechecked next: Smallest mitigation: show the current planner state once near the top of the screen and use a single consistent handoff label on summary rows or footer copy, such as “Open Planner to update,” instead of adding richer explanatory copy throughout.

- Date: 2026-03-21
  Severity: Low
  Area/File(s): read-only `This Week` batch, `WeeklyPlannerContainerView`
  Description: Decision quorum note. The separate-screen pattern plus minimal overview-copy mitigation is safe enough to start now for a first read-only `This Week` slice.
  Why it matters: The current risks are manageable and mostly about framing, not architecture. A separate destination avoids the main workflow-router collision, and the minimal “overview” plus “Open Planner” copy mitigation is enough to prevent most user confusion in the first cut.
  What should be rechecked next: There is no true blocker for starting this read-only slice. The one condition to preserve is scope discipline: keep it read-only, summary-oriented, and clearly subordinate to the existing planner workflow until a stronger generic model layer is in place.

- Date: 2026-03-21
  Severity: Low
  Area/File(s): pending `This Week` delta review checklist
  Description: Review-lane acceptance checks for the running read-only `This Week` slice.
  Why it matters: These are the three highest-signal checks I will apply as soon as Mendel lands the delta, to confirm the slice stayed inside its approved scope.
  What should be rechecked next:
  - Read-only check: the screen must not introduce inline editing, plus/add actions, swipe actions, toggle-like status controls, or any other mutation affordance that implies `PlanItem`-style editing before that model exists.
  - Overview check: the screen must frame itself as a summary of the week rather than as a new workflow state, ideally with one short overview label and without reusing meal-workflow titles in a way that suggests parity with `Suggestions`, `Review`, `Conflict`, or `Finalized`.
  - Planner-subordination check: any actionable path from `This Week` should hand off into the existing planner flow with clear wording such as “Open Planner,” instead of making `This Week` appear to be the primary place to complete weekly planning work.

- Date: 2026-03-21
  Severity: Medium
  Area/File(s): `FamilyPlanPro/Views/WeeklyPlannerContainerView.swift`, `FamilyPlanPro/Views/ThisWeekView.swift`, `FamilyPlanProUITests/FamilyPlanProUITests.swift`
  Description: Verdict: partially fixed. The `This Week` batch landed with the safer separate-screen entry pattern and remains read-only, but it only partially satisfies the overview/subordination checks.
  Why it matters: The good news is the highest structural risk was avoided: `This Week` is opened from a lightweight `NavigationLink`, and the screen itself introduces no inline editing, plus buttons, swipe actions, or toggle-like status controls. The remaining issue is framing: `ThisWeekView` shows `Status: \(plan.status.rawValue.capitalized)`, which surfaces planner-state vocabulary directly, and the handoff copy says `Planner stays for editing meals` rather than the clearer `Open Planner` pattern that would reinforce subordination more explicitly.
  What should be rechecked next: Treat the batch as safe but not fully closed. A small follow-up should:
  - replace raw planner-status wording with calmer overview phrasing
  - tighten the footer or row-level handoff to an explicit `Open Planner` pattern
  - keep the screen otherwise read-only and overview-oriented

- Date: 2026-03-21
  Severity: Medium
  Area/File(s): `This Week` copy, `WeeklyPlannerContainerView`, `FinalizedView`
  Description: Highest-risk vocabulary collision to avoid: any title or intro copy that makes `This Week` sound like a completion state, especially language that overlaps with `Finalized` or implies “this is the week summary.”
  Why it matters: The current planner shell already uses stateful titles and `FinalizedView` opens with “Every meal for the week has been finalized. Here's the summary.” If `This Week` also leads with “summary,” “final plan,” or similarly conclusive language, users can read it as another planner state rather than an overview screen.
  What should be rechecked next: Keep `This Week` vocabulary anchored on “overview” and “open planner” rather than “summary,” “final,” or any wording that sounds like the end-state of the planner workflow.

- Date: 2026-03-21
  Severity: Low
  Area/File(s): `This Week` screen-level handoff copy
  Description: Smallest safe wording pattern for the screen-level handoff hint: “This is an overview of the week. Open Planner to make changes.”
  Why it matters: This keeps the slice read-only and subordinate to Planner with one short cue, while avoiding `Finalized`-style summary/final-state wording.
  What should be rechecked next: When the delta lands, prefer wording close to this pattern rather than richer explanatory copy. The key terms to preserve are `overview` and `Open Planner`.

- Date: 2026-03-21
  Severity: Medium
  Area/File(s): `FamilyPlanPro/Models.swift`, new `WeeklyCheckIn` model, clarified MVP path
  Description: `WeeklyCheckIn` can overlap conceptually with the existing finalized/review meal loop unless its lifecycle is explicitly distinct from `WeeklyPlan.status`.
  Why it matters: Without clear boundaries, “weekly check-in” could be misused as another week-state flag, another notes container, or an implicit approval gate. That would make the current meal workflow harder to reason about and create redundant status concepts.
  What should be rechecked next: Keep `WeeklyCheckIn` narrowly defined in the first cut: a separate weekly artifact with explicit fields and no hidden coupling to meal-state transitions unless the product truly requires it.

- Date: 2026-03-21
  Severity: Medium
  Area/File(s): new `This Week` screen, `FamilyPlanProUITests`, clarified MVP path
  Description: Quick add/edit/status on a new “This Week” screen introduces UI-test brittleness risk unless identifiers and ownership of edit actions are defined from the start.
  Why it matters: The repo has already spent effort stabilizing Grocery List and harness routes. A quick-entry weekly surface can regress into copy-coupled and scroll-fragile tests if it launches without explicit accessibility identifiers and deterministic seeded states.
  What should be rechecked next: For a first read-only slice, this can safely ignore inline edit controls, quick-add affordances, and status toggles entirely. What it must explicitly avoid is visual affordances that look tappable/editable without working behavior. If the screen is read-only, use navigation links or static summary rows only, and postpone inline mutation until identifiers and seeded test paths are designed.

- Date: 2026-03-21
  Severity: Medium
  Area/File(s): new `This Week` screen, clarified MVP path
  Description: Implied editability risk. A read-only “This Week” slice can still accidentally signal editability through plus buttons, checkmarks, swipe affordances, editable row styling, or status chips that look toggleable.
  Why it matters: This is the main thing a safe first slice must avoid. If the UI visually promises quick add/edit/status before the backing generic models and flows exist, users and tests will infer behavior the app cannot support yet.
  What should be rechecked next: In the first slice, prefer static summaries and explicit “Open in Planner” style navigation over inline controls. Add mutation affordances only when the owning model and source-of-truth rules are implemented.

- Date: 2026-03-21
  Severity: Low
  Area/File(s): `FamilyPlanPro/Views/FinalizedView.swift`, `FamilyPlanPro/Views/SuggestionView.swift`, new `This Week` screen
  Description: Status-language drift risk. The existing meal workflow already uses status terms like suggestion, review, conflict, finalized, under/on/over budget, and checked grocery items. A new generic item status on “This Week” can become inconsistent fast if it reuses or overloads those words.
  Why it matters: This is not the main blocker, but it can create product confusion if generic weekly item states read like meal states or vice versa.
  What should be rechecked next: Keep generic item status vocabulary intentionally separate from meal workflow states and document the first-cut set before wiring UI copy and tests.

- Date: 2026-03-21
  Severity: Low
  Area/File(s): `FamilyPlanPro/Models.swift`, `VISION.md`, `STAGED_DELIVERY.md`
  Description: The domain model is still heavily meal-specialized (`WeeklyPlan`, `MealSlot`, `MealSuggestion`, `GroceryList`) rather than centered on a generic weekly coordination abstraction.
  Why it matters: Against the current repo reality, this is transitional debt, not an MVP blocker. Stage 1 is explicitly the meals loop, and the staged plan expects later domains like chores/events/rituals to arrive in later slices rather than through an upfront generic schema rewrite.
  What should be rechecked next: Re-evaluate only when Stage 2/3 work starts. If later domains begin forcing awkward duplication, then the repo will need either a documented “meal-first by design” stance or a measured generalization pass.

- Date: 2026-03-21
  Severity: Medium
  Area/File(s): `FamilyPlanPro/Views/WeeklyPlannerContainerView.swift`, `FamilyPlanPro/Views/FinalizedView.swift`, `VISION.md`
  Description: The app still lacks a broader calm “week view” that unifies what the household needs to know beyond the meal-state machine.
  Why it matters: This is not a Stage 1 blocker for the shipped meal workflow, but it is a real product gap relative to the higher-level vision. Today the user moves between meal workflow states rather than seeing one calm weekly coordination surface.
  What should be rechecked next: Keep this as planned product debt until the stage plan actually asks for cross-domain weekly coordination. It becomes a blocker only if the MVP definition is widened beyond the Stage 1 meal loop.

- Date: 2026-03-21
  Severity: Medium
  Area/File(s): `FamilyPlanPro/Models.swift`, `docs/tech/DATA_MODEL.md`
  Description: The persisted relationship layer is thinner than the conceptual model: several entities rely on weak object references and parent ownership rather than explicit persisted foreign-key style fields and stronger invariants.
  Why it matters: This is a true source-of-truth risk, not just design taste. It overlaps the active model/spec drift issue because it makes family boundaries, cardinality, and lifecycle rules harder to prove or migrate safely.
  What should be rechecked next: Treat this as part of the active model/spec drift item rather than as a separate architecture rewrite. The immediate decision is whether to narrow the spec to the current schema or harden the schema where the weak links are actually causing risk.

- Date: 2026-03-21
  Severity: Low
  Area/File(s): `FamilyPlanPro/Models.swift`, `STAGED_DELIVERY.md`, `VISION.md`
  Description: There is no generic weekly action model spanning meals, chores, events, and rituals.
  Why it matters: In the current repo, this is transitional debt rather than a blocker. The staged plan intentionally starts with dedicated meal entities, and no current acceptance criterion requires a cross-domain `WeeklyAction`-style abstraction yet.
  What should be rechecked next: Reassess when Stage 2+ domains land. If multiple domains start repeating the same scheduling/ownership/status patterns, then a shared weekly-action abstraction may become justified.

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
