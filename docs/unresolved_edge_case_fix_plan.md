# Unresolved Edge Case Fix Plan

Status: Updated on 2026-03-21 after re-grounding on Aristotle's current model/spec drift evidence: the active batch is now doc/model source-of-truth alignment, with the smallest safe slice narrowed to a doc-only Stage 1 data-model spec reset rather than persisted model changes.

## Current Decision

Next action:
- Treat the Grocery List smoke-path batch as complete.
- Treat the Grocery List deletion-undo batch as complete.
- Treat the harness-consistency batch as functionally resolved.
- Defer any remaining contract-clarity debt from that batch.
- Redirect the active slot to model/spec source-of-truth drift between `FamilyPlanPro/Models.swift` and `docs/tech/DATA_MODEL.md`.
- Keep the smallest safe action doc-only unless Aristotle's evidence shows an immediate Stage 1 behavior bug that cannot be contained that way.
- Hold queued UI and notification issues behind this source-of-truth batch.

Current routing:
- Manual add/edit visibility risk is treated as fixed on the product side.
- The Grocery List smoke-path blocker is treated as closed after verification.
- Grocery List deletion undo is treated as fixed on the product side and directly proven by Mendel's UI verification slice.
- The harness-consistency issue is closed at functional scope.
- Residual contract-clarity debt from the harness batch is deferred.
- Aristotle's current evidence splits the model/spec drift into:
  - true functional risks
  - documentation-only drift
- The true functional risks are:
  - family ownership not enforced as `DATA_MODEL.md` specifies
  - `WeeklyPlan` identity relies on `startDate` rather than an explicit unique `(familyId, year, isoWeek)` shape
  - `MealSuggestion` cardinality/lifecycle differs from the spec's 1-N description
- Documentation-only drift includes:
  - spec-only common fields and timestamps
  - future-stage entities and invariants not present in Stage 1 code
- The active issue is now the doc/model source-of-truth mismatch itself, with doc-only narrowing as the leading candidate.

Verification gate:
- Grocery List verification has cleared for the prior smoke-path batch.
- Aristotle's fresh log acknowledges the product-side fix.
- Boole reports build green and nearby Grocery List smoke coverage green.
- Mendel reports direct UI verification passed for delete -> undo -> restored item.
- The adjacent workflow test `testReopenFromFinalizedReturnsToSuggestions` also passed.
- No further Grocery List verification follow-up is required unless Aristotle re-opens the batch.
- Boole and Aristotle together now support closing the harness-consistency batch at functional scope.
- Any remaining remainder is treated as contract-clarity debt, not an active functional blocker.
- The new active slice should stay source-of-truth-first and avoid persisted model changes unless a concrete Stage 1 runtime bug requires them.

Coordination rule:
- Keep this file focused on issue selection, status, and safe sequencing.

## Lane Status

Active now:
- `docs/tech/DATA_MODEL.md`
  - Narrow Stage 1 doc-only narrowing candidate to match the actual persisted model surface.

Pending verification:
- None until the plan decision is executed.

Queued next candidates from Aristotle's current log:
- `FamilyPlanProUITests/FamilyPlanProUITests.swift`
  - UI tests still depend on older user-facing copy in places.
- `FamilyPlanPro/Views/FinalizedView.swift`
  - Finalized cadence copy alignment should be reconsidered only if Aristotle keeps it active after this source-of-truth pass.
- `FamilyPlanPro/FamilyPlanProApp.swift`, `FamilyPlanPro/Notifications/GroceryCadenceScheduler.swift`
  - Notification authorization behavior differs across debug-route and `UITEST_STATUS` harnesses.
- `FamilyPlanPro/DataManager.swift`, `FamilyPlanPro/Views/WeeklyPlannerContainerView.swift`
  - Multi-family source-of-truth behavior is underspecified for Stage 1.
- `FamilyPlanPro/Models.swift`, `docs/tech/DATA_MODEL.md`
  - Data-model docs and persisted model shapes diverge materially.

Queue rule:
- Promote only one next-step issue at a time.
- Prefer the smallest active-stage user-facing or verification gap before doc/harness cleanup.

## Status

Implemented so far:
- `FamilyPlanProUITests/FamilyPlanProUITests.swift`
  - Replaced brittle hard-coded grocery section identifiers with a grouped-section check based on visible weekday headers.
  - Hardened the manual add/edit path by:
    - recording grocery text-field count before add
    - polling for a new field after `Add Item`
    - interacting with the newest field
    - dismissing the keyboard after typing
    - asserting the typed value
- `FamilyPlanPro/Views/GroceryListView.swift`
  - Added a brief orientation section at the top of the screen.
  - Added a simple completion summary.
  - Replaced the empty-state placeholder text with a clearer `ContentUnavailableView`.
- `CHANGELOG.md`
  - Added a narrow Stage 1 entry for Grocery List empty-state guidance and manual item smoke-path hardening.

Still unresolved:
- The Grocery List deletion-undo batch is closed unless Aristotle reports a new regression.
- The harness-consistency batch is closed at functional scope.
- Residual contract-clarity debt from the harness batch is deferred.
- The active unresolved lead issue is model/spec source-of-truth drift between `Models.swift` and `DATA_MODEL.md`.
- Within that batch, the smallest safe active slice is doc-only narrowing unless a runtime Stage 1 bug must be fixed in code.
- UI-test copy brittleness remains queued, not active.

Recorded verification result for the completed batch:
- Build passed.
- The targeted Grocery List smoke-path verification is treated as complete/cleared by Boole.
- Direct UI verification passed for delete -> undo -> restored item.
- Adjacent reopen-flow verification passed via `testReopenFromFinalizedReturnsToSuggestions`.
- Aristotle’s current log still contains historical Grocery List entries, but this plan now treats that batch as closed unless Aristotle re-opens it with a new concrete failure.
- Aristotle’s reconciled log now marks the prior Grocery List entries as fixed/regression-watch items, not active lead candidates.

Implementation status for the active batch:
- No code or doc change has been routed yet for the model/spec drift batch.
- Current batch state:
  - Planning only.
  - The primary decision is whether to narrow the spec to the actual Stage 1 model surface or to change persisted models.

Next issue selection:
- Keep exactly one active issue.
- Choose the smallest safe slice within the model/spec drift batch first.
- Do not promote any queued UI, notification, or cadence issue while the source-of-truth batch is active.
- Prefer doc-only narrowing over model changes unless a concrete runtime bug cannot be safely deferred.

Active planning stance:
- File target first: `docs/tech/DATA_MODEL.md`
- Optional supporting note only if needed later: `README.md` or adjacent docs, not app code
- User value target: restore one truthful source of truth for the Stage 1 data model so future work is planned against reality
- Current status: planning only

## Candidate Issues

- High: `DATA_MODEL.md` overstates current Stage 1 persisted guarantees compared with `Models.swift`.
- Medium: Family ownership constraints are not enforced as the spec currently claims.
- Medium: `WeeklyPlan` identity in code does not match the spec's unique `(familyId, year, isoWeek)` shape.
- Medium: `MealSuggestion` cardinality/lifecycle in code does not match the spec's 1-N description.
- Medium: UI tests are overly coupled to user-facing copy.
- Medium: Notification authorization behavior may still differ across test harness entry points.
- Medium: Current-week bootstrap still treats the first fetched family as the effective app-wide default family.
- Medium: Persisted model shapes still diverge materially from `docs/tech/DATA_MODEL.md`.
- Low: Grocery flag-off behavior needs a clean recheck after the grocery smoke path is stable.
- Low: Architecture docs do not fully match the current implementation.

## Validated Now

- Resolve now:
  - Grocery UI smoke brittleness around add/edit. Completed.
  - Manual grocery item visibility/focus only if the UI-test-only hardening does not fully resolve the issue. Completed.
  - UI-test copy brittleness, but only as part of the same narrow grocery test pass. Completed as part of the batch.
- Verify now:
  - Treat the Grocery List deletion-undo batch as closed unless Aristotle reports a regression.
- Resolve now:
  - Decide and execute the smallest safe source-of-truth action for `DATA_MODEL.md` versus `Models.swift`.
- Defer for now:
  - Residual harness contract-clarity cleanup.
  - Notification side-effect unification across all test entry points.
  - Current-family / multi-family source-of-truth clarification.
  - Grocery flag-off re-verification.
  - Architecture doc reconciliation.

Rationale:
- The top Stage 1 Grocery List blocker has already been cleared.
- The deletion-undo issue is now directly proven and does not justify more immediate work.
- The harness-consistency issue is functionally closed and no longer deserves the active slot.
- Aristotle's latest evidence distinguishes between true functional risks and documentation-only drift inside the model/spec mismatch.
- The smallest safe next move is still doc-only narrowing because:
  - the spec currently overclaims fields, invariants, and future-stage entities beyond the actual Stage 1 model
  - changing persisted models to match the spec would create schema, migration, and behavior risk far beyond one slice
  - the identified functional risks are real, but they are broader than a single safe model migration slice and are better captured explicitly as deferred runtime risks unless one is chosen as its own later active bug-fix slice
- So the right immediate slice is to narrow `DATA_MODEL.md` to the real Stage 1 persisted model surface and explicitly call out deferred invariants rather than silently implying they already exist.

## Deferred

- Runtime model-alignment changes for family ownership enforcement.
  - Defer because this is a real behavior/invariant gap, but it is not the smallest safe slice compared with spec narrowing.
- Runtime model-alignment changes for `WeeklyPlan` identity uniqueness.
  - Defer because adding `(familyId, year, isoWeek)` identity is a schema/behavior migration, not a safe doc-lane slice.
- Runtime model-alignment changes for `MealSuggestion` cardinality/lifecycle.
  - Defer because this likely touches workflow behavior, relationships, and persistence semantics beyond one safe planning-only slice.
- Residual harness contract-clarity debt.
  - Defer because the functional batch is closed and the remainder is no longer an active behavior mismatch.
- Notification side-effect isolation across every test harness.
  - Defer because it likely spans `FamilyPlanProApp`, notification scheduler code, and test harness behavior.
- Grocery-related flag-off re-verification.
  - Defer until the primary grocery UI smoke path is stable.
- Architecture doc cleanup beyond the Stage 1 data-model narrowing.
  - Defer because the active source-of-truth slice should stay limited to `DATA_MODEL.md`.

### Plan E: Stage 1 data-model spec narrowing

Goal:
- Narrow `docs/tech/DATA_MODEL.md` so it truthfully describes the Stage 1 persisted model surface that actually exists in `FamilyPlanPro/Models.swift`, while explicitly tagging deferred invariants and future-stage aspirations.

Preferred file ownership:
- Worker 1 only: `docs/tech/DATA_MODEL.md`

Smallest safe implementation target:
- Keep the slice doc-only and one-file-first.
- Do not mutate persisted models, relationships, or schema in this batch.

Acceptance boundaries for this slice:
1. `DATA_MODEL.md` no longer claims Stage 1 persisted fields/invariants that the code clearly does not implement.
2. Stage 1 entities in the doc map cleanly to the actual `@Model` types and their persisted fields/relationships.
3. Spec-only future-stage fields and entities are either removed from the canonical Stage 1 description or explicitly marked as future/deferred.
4. The doc explicitly calls out the known deferred runtime risks instead of implying they are already enforced.

Explicitly out of scope for this slice:
- Changes to `Models.swift`
- SwiftData schema or migration work
- DataManager workflow changes
- Family ownership enforcement
- `WeeklyPlan` identity redesign
- `MealSuggestion` lifecycle/cardinality changes
- Broader architecture/doc cleanup outside `DATA_MODEL.md`

Doc-only versus model-change assessment:
- Doc-only narrowing is the right next move.
- Reason:
  - the currently observed mismatch is larger than one safe runtime migration slice
  - the spec currently functions as a false source of truth for multiple areas at once
  - narrowing the spec restores truthful planning ground immediately without risking persisted data
- Model changes should be split into later runtime slices only if individually promoted, for example:
  - family ownership enforcement
  - `WeeklyPlan` uniqueness/identity
  - `MealSuggestion` relationship/lifecycle cleanup

Immediate reconciliation paths once Aristotle reviews:
- If Aristotle says `closed`:
  - mark the doc/spec drift batch closed at documentation scope
  - record that `DATA_MODEL.md` now matches the actual Stage 1 model surface closely enough to be the truthful planning reference
  - promote UI-test copy brittleness as the next smallest safe follow-up
- If Aristotle says `partially fixed`:
  - keep the doc/spec drift batch active
  - record whether the remaining issue is:
    - a remaining Stage 1 doc overclaim
    - a still-unclear deferred-runtime-risk note
    - an area where the doc still mixes Stage 1 reality with future-stage aspirations
  - narrow the next action to one smallest remaining doc/source-of-truth adjustment only
  - do not promote queued issues yet

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
