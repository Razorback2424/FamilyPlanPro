# Unresolved Edge Case Fix Plan

Status: Updated on 2026-03-22 for the likely smallest safe planner-density reduction slice. Planning remains read-only and async only.

## Current Decision

Next action:
- Keep Grocery List smoke-path, deletion-undo, harness-consistency, cadence-copy, and the first read-only `This Week` overview batches closed.
- Treat the active issue as a narrow planner-density reduction pass in `SuggestionView`.
- Prefer removing the day-by-day ownership-rule editing UI from `SuggestionView` while preserving current ownership behavior.
- Hold migration compatibility, broader MVP generalization, and source-of-truth work behind this UI-density batch.

Current routing:
- The `This Week` slice is treated as landed and no longer active here.
- The active issue is planner density inside `SuggestionView`.
- The smallest safe route is to remove the day-by-day defaults editor from the Suggestions screen, not to redesign ownership rules.
- Do not widen this into ownership-rules behavior changes, family-default redesign, or generic action work.

Verification gate:
- The minimum likely verification for this density-reduction batch is:
  - `build`
  - one narrow Suggestions UI smoke check if the repo already covers the surrounding screen behavior
- If no targeted UI proof is available, keep verification to build plus focused review that ownership inheritance and per-meal assignment still work.

Coordination rule:
- Keep this file focused on issue selection, active status, acceptance boundaries, and exact deferrals.
- Do not block the worker lane while formalizing decisions already converged by review + implementation-prep + verification lanes.

## Lane Status

Active now:
- `FamilyPlanPro/Views/SuggestionView.swift`
  - likely one-file-first density reduction target

Pending verification:
- `build`
- optional narrow Suggestions UI smoke or existing ownership-path check if already present

Queued next candidates:
- `FamilyPlanProUITests/FamilyPlanProUITests.swift`
  - UI-test copy brittleness cleanup
- `FamilyPlanPro/Models.swift`
  - `Family.defaultOwnershipRulesJSON` migration compatibility
- `docs/tech/DATA_MODEL.md`
  - doc/model source-of-truth narrowing
- `FamilyPlanPro/FamilyPlanProApp.swift`, `FamilyPlanPro/Notifications/GroceryCadenceScheduler.swift`
  - remaining harness contract-clarity cleanup

Queue rule:
- Keep exactly one active implementation batch.
- Do not promote `PlanItem`, `WeeklyCheckIn`, quick add/edit/status, or the generic action system while this compatibility batch is active.

## Active Batch

### Plan H: SuggestionView Density Reduction

Goal:
- Reduce visual and interaction density in `SuggestionView` without breaking ownership behavior.

Preferred file ownership:
- Worker lane only:
  - `FamilyPlanPro/Views/SuggestionView.swift`
- Optional test file only if the repo already has a narrow surrounding Suggestions UI check:
  - `FamilyPlanProUITests/FamilyPlanProUITests.swift`

Smallest safe implementation target:
- Remove the `Ownership Rules` section from `SuggestionView`.
- Keep all existing slot-level ownership reads and per-meal responsible selection intact.
- Leave editing of family weekday defaults in `FamilySettingsView` only.
- Avoid touching `DataManager` or ownership snapshot generation in this slice.

Acceptance boundaries for this slice:
1. `SuggestionView` no longer shows the day-by-day defaults editor.
2. Existing slot ownership still comes from the already-resolved plan/slot state (`slot.owner`, saved suggestion responsible user, or explicit per-meal selection).
3. Users can still change the responsible person for an individual meal suggestion from the existing per-slot entry controls.
4. Family weekday defaults remain editable only in `FamilySettingsView`.
5. No ownership snapshot regeneration or default-propagation logic changes are introduced.

Likely fix shape:
- Delete the `Ownership Rules` section and its explanatory copy from `SuggestionView`.
- Keep the existing `responsibleSelections` and `defaultResponsibleSelection(for:)` flow intact so slot-level owner fallback still works.
- Keep `saveSuggestions` and unassigned-owner validation untouched.
- Do not remove ownership defaults from the product; only remove the day-by-day editor from the Suggestions surface.

Safest removal assessment:
- The safest way to remove day-by-day defaults from `SuggestionView` is UI-only:
  - remove the section rendering and its local picker bindings
  - do not change `updateOwnershipRule(for:)` usage anywhere else unless it becomes dead code as a direct result
  - preserve `slot.owner` fallback and saved responsible-user logic exactly as-is
- Why this is safest:
  - ownership behavior is currently carried by `plan.ownershipRulesSnap`, `slot.owner`, and per-meal responsible selections
  - the risky part is editing defaults in the weekly Suggestions screen, not reading/applying already-resolved owners
  - leaving `FamilySettingsView` as the single editor avoids behavior drift while reducing Suggestions density

Explicitly out of scope for this slice:
- `DataManager` rule-generation changes
- `OwnershipRulesSnap` redesign
- `FamilySettingsView` redesign
- family default ownership behavior changes
- migration compatibility for `defaultOwnershipRulesJSON`
- doc/model source-of-truth narrowing
- `PlanItem`
- `WeeklyCheckIn`
- quick add/edit/status
- generic action system

## Status

Implemented so far in earlier batches:
- Grocery List smoke-path hardening
- Grocery delete/undo proof
- harness-consistency functional fix
- finalized cadence copy alignment

Current batch state:
- Planning only
- Likely one-file-first UI-density fix
- No evidence yet that broader ownership-behavior changes are required

Current execution stance:
- Favor a one-file `SuggestionView` reduction before any ownership-behavior redesign.
- Treat this as a narrow product-surface simplification, not an ownership-rules rewrite.

## Deferred

- `PlanItem` model introduction
  - Defer because it is unrelated to this density-reduction slice.
- `WeeklyCheckIn` model introduction
  - Defer because it is unrelated to this density-reduction slice.
- quick add/edit/status for arbitrary weekly items
  - Defer because it is unrelated to this density-reduction slice.
- generic action system
  - Defer because it is unrelated to this density-reduction slice.
- ownership-rules product redesign
  - Defer because the active need is to simplify Suggestions, not redesign defaults.
- migration compatibility for `defaultOwnershipRulesJSON`
  - Defer because it is a separate compatibility batch and should not be combined with this UI simplification.

## Rationale

- The density problem is local to `SuggestionView`, not to the ownership model itself.
- The smallest safe response is to remove the weekly defaults editor from Suggestions while preserving slot-level ownership behavior.
- The cleanest source-of-truth pattern is:
  - family weekday defaults are edited in `FamilySettingsView`
  - Suggestions consumes already-resolved ownership state and per-meal overrides only

## Implementation Plan

### Plan A: Completed Grocery List smoke-path batch

Goal:
- Make the grocery UI smoke path reliably prove grouped sections plus manual item add/edit without changing product behavior unless clearly necessary.

Recommended ownership:
- Worker 1: `FamilyPlanProUITests/FamilyPlanProUITests.swift`
- Optional Worker 2 only if needed after verification: `FamilyPlanPro/Views/GroceryListView.swift`

Steps:
1. Harden the single failing grocery UI smoke test in `FamilyPlanProUITests.swift`.
   - Prefer stable intent checks over hard-coded section identifiers that depend on exact seeded weekday numbers.
   - Assert grouped sections via visible weekday headers or another stable grouped-list signal.
   - For add/edit, prefer the smallest robust path:
     - record field count before add
     - tap `Add Item`
     - wait for field count increase or a new grocery field to exist
     - type into the newest/empty field
     - dismiss the keyboard if present
     - assert the typed value
     - stop there
2. Re-run the narrow grocery UI verification on a clean simulator.
3. Only if the test still fails because the UI does not reliably reveal the new field, make one minimal product-side fix in `GroceryListView.swift`.
   - Candidate product-side fix:
     - add one stronger accessibility hook or deterministic insertion/focus cue for the new row
   - Avoid broader UI redesign.
4. Re-run build plus the same narrow UI command.
5. If green, add one short changelog entry only if the repo is already logging similarly narrow Stage 1 grocery usability slices in the active branch.

Status against Plan A:
- Implemented:
  - grouped-section assertion no longer depends on brittle seeded weekday identifiers
  - add/edit test path now waits for the new field, targets the newest field, dismisses the keyboard, and asserts typed value
  - Grocery List screen now has orientation copy and stronger empty-state guidance
  - changelog entry has been added
- Verified complete:
  - final UI-test proof is treated as cleared by Boole
  - manual add/edit visibility risk is treated as closed for this batch

### Plan B: One-file product-side follow-up in `GroceryListView.swift`

Goal:
- Make newly added manual grocery items more deterministically visible and editable on longer lists without widening scope beyond the current Stage 1 Grocery List screen.

Required file ownership:
- Worker 1 only: `FamilyPlanPro/Views/GroceryListView.swift`

Concrete implementation target:
- Keep `addItem()` behavior local to `GroceryListView.swift`.
- Add one minimal view-local mechanism so the newest inserted manual item is easier to reveal and edit immediately.

Recommended shape:
1. Track the newest inserted grocery item ID in local view state.
2. Wrap the list content in a `ScrollViewReader` or equivalent local scrolling mechanism.
3. When `Add Item` inserts a blank item:
   - append and save as it does today
   - record that new item’s ID in local state
4. On the next render/update:
   - scroll to the newly inserted item row using its ID
   - keep the behavior local to the Grocery List screen only
5. If a full scroll-to-row implementation is too invasive for this slice, the fallback is:
   - add a deterministic accessibility identifier tied to the newest inserted blank row so the test can target it without guessing position
   - do not combine that fallback with unrelated row redesign

Explicit guardrails:
- Do not change `GroceryItem` persistence shape.
- Do not add global focus-management abstractions.
- Do not redesign row layout or grouping.
- Do not touch tests in the same implementation step unless verification later proves the view-side fix requires a matching narrow test adjustment.
- Do not combine this with undo/delete work.

Status against Plan B:
- Aristotle’s latest routing treats the manual add/edit visibility risk as fixed on the product side.
- Boole’s verification result allows Plan B to be treated as completed/closed for this batch.
- Re-open Plan B only if Aristotle or a later verifier reports a new concrete product-side failure in `GroceryListView.swift`.

### Plan C: Grocery List deletion undo

Goal:
- Add a minimal in-screen restore path for accidental grocery item deletion on the Grocery List screen, aligned with the Stage quality bar for destructive actions.

Implementation status:
- Implemented by Mendel in `FamilyPlanPro/Views/GroceryListView.swift`.
- Reported build status: success.
- Aristotle's fresh verdict: fixed in the product-side implementation, pending verification.
- Boole's verification result: build green, nearby Grocery List smoke coverage green, direct delete/undo proof still missing.

Preferred file ownership:
- Worker 1 only: `FamilyPlanPro/Views/GroceryListView.swift`

One-file-first implementation target:
- Keep the initial solution entirely within `GroceryListView.swift` if possible.

Recommended shape:
1. Capture the deleted `GroceryItem` values in view-local transient state when a row is deleted.
   - Store only the minimum data needed to restore the item in the current list view.
2. After deletion, present a lightweight in-screen undo affordance.
   - Prefer a local `safeAreaInset` banner or similar transient control over a broad navigation or model change.
   - Include a single `Undo` action.
3. If the user taps `Undo` within the current screen session:
   - recreate or reinsert the deleted item into the current list
   - preserve the important user-facing values such as name, checked state, and day assignment
4. If the user does nothing:
   - allow the deletion to remain final without extra prompts
5. Keep the behavior limited to one recent deletion batch unless a broader design is proven necessary.

Conflict-aware guardrails:
- Do not change persisted model shapes.
- Do not add app-wide undo infrastructure.
- Do not change grocery grouping/generation/cadence logic.
- Do not combine this with Grocery List row redesign or notification work.
- Avoid touching tests in the first implementation step unless the final chosen affordance requires a narrow matching update.

Why this is the smallest safe plan:
- It stays on the existing Grocery List screen.
- It can likely be implemented inside one view file with local transient state.
- It satisfies the stated user need without introducing broad infrastructure.

Potential escalation only if one-file-first fails:
- If restoring deleted items cannot be done safely inside `GroceryListView.swift` alone, the next expansion should be minimal and explicit:
  - `FamilyPlanPro/Views/GroceryListView.swift`
  - one supporting model/persistence file only if required to preserve the deleted row accurately
  - no wider DataManager or architecture changes by default

### Explicit non-goals for this plan

- Do not change grocery generation logic.
- Do not change cadence eligibility logic.
- Do not redesign Grocery List grouping.
- Do not combine deletion undo with any other Grocery List improvement in the same batch.
- Do not unify all launch harnesses in the same batch.

### Plan D: Launch-state contract alignment

Goal:
- Remove the immediate ambiguity between legacy `UITEST_STATUS` values and newer debug-route values by establishing one authoritative launch-state mapping path.

Status:
- Functionally closed.
- Residual contract-clarity debt deferred.

Preferred file ownership:
- Worker 1: `FamilyPlanPro/FamilyPlanProApp.swift`
- Optional Worker 2 only if needed for matching test-launch cleanup: `FamilyPlanProUITests/FamilyPlanProUITests.swift`

Smallest safe implementation target:
- Keep the change limited to launch-state interpretation, not broader test harness redesign.

Recommended shape:
1. Identify the authoritative route/state mapping already closest to current usage.
   - Prefer the newer debug-route vocabulary if it already covers more current screens.
2. Make the secondary entry path delegate into that authoritative mapping instead of maintaining a parallel independent mapping.
   - Example: normalize `UITEST_STATUS` values into one internal debug-route representation before seeding state.
3. Keep existing external launch arguments/env keys working for now.
   - This slice should reduce drift without forcing every caller to change immediately.
4. Add or update one narrow UI-test launch helper/assertion only if needed to prove the mapping remains equivalent for the currently used flows.
5. Do not touch notification suppression behavior in the same slice.

Guardrails:
- Do not redesign the entire app launch harness.
- Do not rename every launch argument in the same step.
- Do not combine this with UI-test copy cleanup.
- Do not change workflow seeding beyond the minimum required to make both entry paths converge.

Why this is the smallest safe plan:
- It addresses the source-of-truth split directly.
- It can likely stay within one app file plus optional small UI-test cleanup.
- It reduces future screenshot/UI-test drift without opening broader harness or notification work.

Acceptance boundaries for this slice:
1. One launch-state mapping path is clearly authoritative in app code.
2. The secondary launch entry path delegates into that same mapping instead of maintaining its own parallel route/status interpretation.
3. Existing currently used launch inputs continue to work for the covered Stage 1 flows.
4. The change does not alter user-facing workflow behavior outside launch-state seeding.
5. The delta stays limited to harness/state-entry alignment, not broader app initialization refactoring.

Explicitly out of scope for this slice:
- Notification authorization suppression or scheduler changes.
- Debug screenshot-route redesign beyond what is required to delegate into the same mapping.
- Full removal of legacy launch inputs if compatibility shims are sufficient.
- UI-test copy brittleness cleanup.
- Feature-flag behavior changes unrelated to launch-state mapping.
- Model, persistence, or DataManager source-of-truth changes.

Reconciliation checklist when Mendel's delta returns:
- Did the implementation actually converge the two launch-state paths, or only rename one side?
- Is there still any duplicated route/status mapping logic left in parallel?
- Did the delta widen into notification handling, feature flags, or unrelated startup behavior?
- Are the currently exercised Stage 1 seeded routes still represented after the change?
- Did any new test-only vocabulary get introduced that creates another parallel contract?

Reconciliation branch if Aristotle says `closed`:
- Mark the harness-consistency batch complete.
- Record which path is now authoritative and that the secondary path delegates to it.
- Record that route/value vocabulary is now normalized enough that the two entry paths no longer describe the same seeded states with conflicting names.
- Record that notification behavior remains at parity for the scoped launch paths in this batch, or that it was intentionally held neutral by the change.
- Move launch-state inconsistency out of the active slot and into verified/closed history.
- Keep notification-isolation work deferred unless Aristotle explicitly says the delta exposed it.
- Only after closure, re-evaluate the queued UI-test copy brittleness issue as the next smallest safe follow-up.

Reconciliation branch if Aristotle says `partially fixed`:
- Keep the harness-consistency batch active.
- Record exactly which ambiguity remains:
  - duplicated mapping logic still present
  - only some routes normalized
  - legacy path still diverges from debug-route path
  - route/value vocabulary still diverges across equivalent seeded states
  - notification behavior still differs across the scoped launch paths
  - verification gap rather than product gap
- Narrow the follow-up to one smallest remaining contract-alignment step only.
- Do not promote the queued UI-test copy brittleness issue.
- Keep notification and broader harness redesign explicitly out of scope unless Aristotle says the remaining failure cannot be isolated without them.

Immediate post-verdict update if Aristotle says `closed` and Boole's narrow verification also passes:
- Mark the harness-consistency batch closed on combined review + verification evidence.
- Record that:
  - launch-state mapping is unified for the scoped flows
  - route/value vocabulary parity is acceptable for the batch
  - notification behavior is either parity-safe for scoped flows or unchanged/neutralized by design
- Clear the active slot.
- Keep queued issues visible.
- At that point, the next smallest safe queued issue becomes eligible for promotion, but only after this combined closure is recorded.

Immediate post-verdict update if Aristotle says `partially fixed`:
- Keep the harness-consistency batch in the active slot.
- Wait for or incorporate Boole's narrow verification result only as evidence about the landed slice, not as permission to promote queued issues.
- Record the smallest remaining gap in one of these narrow forms:
  - residual route/value vocabulary split
  - residual notification parity difference in the scoped flows
  - residual duplicated mapping logic
  - verification-only gap where behavior may already be aligned
- Keep the next queued issue visible but unpromoted.
- Narrow the next action to one smallest remaining harness-consistency follow-up only.

Immediate reconciliation once Boole returns after Aristotle `partially fixed`:
- If Boole shows equivalent launch inputs now land on the same scoped seeded states:
  - treat the remaining issue as documentation/clarity debt only unless Aristotle identified a concrete functional difference that still reproduces
  - close the functional portion of the active batch
  - keep any residual naming/clarity debt attached to this batch only if it is still needed for accurate source-of-truth communication
  - do not promote queued issues until that closure is explicitly recorded
- If Boole still finds divergent seeded behavior, divergent notification behavior in scope, or surviving duplicated mapping effects:
  - keep the harness-consistency batch active
  - record the smallest remaining functional mismatch only
  - do not downgrade the issue to documentation/clarity debt
  - do not promote queued issues

Queued-issue freeze rule for this batch:
- Do not promote the queued UI-test copy-brittleness issue until both conditions are satisfied:
  - Aristotle has issued a verdict on the active harness-consistency batch
  - Boole's narrow verification has either closed the batch or the batch has been explicitly narrowed again as still active

Minimum acceptable closure condition for this batch:
- The app has one authoritative launch-state mapping for the scoped Stage 1 seeded flows.
- The secondary launch path delegates into that mapping instead of maintaining an independently drifting interpretation.
- The currently exercised seeded flows land on equivalent app states regardless of whether they come from legacy `UITEST_STATUS` inputs or debug-route inputs.
- Any remaining debug-route alias parity issue is limited to naming/compatibility cleanup rather than divergent seeded behavior.
- Any such alias parity remainder is small enough to be tracked as a follow-up without keeping the main harness-consistency batch open.

Closure boundary for a deferred alias follow-up:
- Accept closure if debug-route aliases still need minor normalization, as long as:
  - they resolve to the same seeded route/state as the authoritative mapping
  - they do not create different notification behavior within the scoped flows
  - they do not require parallel mapping logic to remain in place
- Do not accept closure if alias handling still changes seeded behavior, leaves duplicated mapping branches, or preserves conflicting route/value vocabularies for the same state.

## Verification

Next required verification only:
- For the active data-model doc slice, verify only that the canonical doc no longer overclaims Stage 1 persisted behavior relative to `Models.swift`.

Blocking rule:
- Do not propose or route runtime model changes, queued UI-test cleanup, or broader architecture/doc work while the active data-model spec slice remains unresolved.

### Next smallest safe follow-up

Scope:
- one narrow doc-only one-file-first slice

Preferred file target:
- `docs/tech/DATA_MODEL.md`

Goal:
- reconcile the canonical data-model doc with the actual Stage 1 persisted model surface

Guardrails:
- do not change `Models.swift`
- do not combine this with migration or workflow fixes
- keep the slice limited to truthful Stage 1 doc narrowing plus explicit deferred-risk notes

## Risks

- The UI test may still be flaky even after hardening if simulator focus/keyboard behavior remains unstable.
- A view-local undo path can still lose fidelity if deleted item state is not captured carefully before deletion.
- Expanding beyond `GroceryListView.swift` too early would increase coordination risk.
- A transient undo affordance must not block normal list interaction or reopen unrelated state-machine concerns.

## Verification

Completed verification for the closed batch:
- Build passed.
- Grocery List smoke-path verification is recorded as cleared by Boole.
- Direct delete -> undo UI verification passed.
- `testReopenFromFinalizedReturnsToSuggestions` passed.

Next verification need:
- For the next slice, verify only:
  - the doc no longer claims family ownership enforcement, `WeeklyPlan` identity guarantees, or `MealSuggestion` lifecycle/cardinality behavior that the current code does not implement
  - future-stage/spec-only fields are clearly labeled as deferred rather than current Stage 1 reality
