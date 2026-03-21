# STAGED_DELIVERY.md
Operational plan for delivering Family Plan Pro in sequential, fully testable stages. Each stage is self-contained with explicit scope, gates, and rollback. No code here—only what must be true to ship.

---

## Governance

Decision cadence
- One stage per release branch, merged to `main` only after Go.
- No parallel stage work on `main`; use feature flags for behind-the-scenes prep.

Definition of Done (applies to every stage)
- Functional acceptance criteria met and demonstrated in a short screen recording.
- Tests pass: unit, UI smoke, and performance gates.
- Accessibility checks pass (VoiceOver labels, Dynamic Type, contrast AA).
- Migrations verified on an instance seeded with last stage’s data.
- README, CHANGELOG, STAGED_DELIVERY updated in the same PR.

Shared quality bars
- Cold start to Current Week: ≤ 1s (release build, simulator).
- Current Week render: ≤ 200ms with representative data.
- Undo path for any destructive action inside the current screen.
- Telemetry is opt-in and uses counts/durations only (no content).

Artifacts required at Go/No-Go
- 2–3 minute demo video (scripted path).
- Test run output (attached from CI or local).
- Accessibility/contrast screenshots for new views.
- Migration dry-run notes (input dataset, observed results).
- CHANGELOG entry and Stage checklist pasted into PR description.

---

## Stage 0 — Baseline Stabilization

Goal
- Make the current weekly meal-planning foundation airtight and observable.

Scope
- WeeklyPlan lifecycle: Suggestion → Review → Finalized (idempotent transitions).
- Auto-create or roll Current Week on first open; show Finalized read-only summary.
- CRUD hardening for Families, Users, WeeklyPlans, MealSlots, MealSuggestions.
- Demo data seeding and a Reset Demo control.

Non-goals
- New features, notifications, calendar, grocery, or budget logic.

Feature flags
- None (foundation only).

Acceptance criteria
- Opening app with no data creates a Current Week in Suggestion.
- Transitioning between states is reversible back to Suggestion.
- No orphaned MealSlots or MealSuggestions after deletes/edits.
- Finalized view is read-only and reflects the plan accurately.

Test plan
- Unit: state transitions; cleanup invariants; “get or create Current Week”.
- UI: Suggest → Review → Finalize happy path; backtrack; delete/edit slot.
- Perf: startup and week load thresholds met.

Data & migration
- Ensure default initializers on all persisted types.
- Include a one-time “bootstrap to Stage 0” guard to heal inconsistent weeks and create a default Family + Current Week with 7 meal slots when empty.

Rollback
- Revert to previous build; keep Stage 0 migration non-destructive.

Go/No-Go checklist
- [x] Demo video shows create → plan → finalize → reopen.
- [x] Unit/UI tests green; performance thresholds met.
- [x] Accessibility checks captured.
- [x] Reset Demo reseeds correctly.

Stage 0 approved complete by owner on 2026-02-02; verification evidence (tests/perf/accessibility) deferred.

---

## Stage 1 — Meals to Vision (Ownership, Simple Friday, Grocery, Budget, Cadence)

Goal
- Elevate meals to the envisioned experience before adding other domains.

Scope
- Ownership rules by day (snapshot per week).
- “Simple Friday” labeling and templates.
- GroceryList auto-generated from Finalized meals.
- Sun/Thu grocery nudges (local notifications).
- Budget status: under / on / over threshold per week.

Non-goals
- External grocery providers; cross-family sharing.

Feature flags
- `ff.meals.ownershipRules`
- `ff.meals.groceryList`
- `ff.notifications.groceryCadence`
- `ff.meals.budgetStatus`

Acceptance criteria
- On week start, slots inherit owners by rule; Friday labeled Simple.
- Finalizing creates a single GroceryList grouped by day; items editable.
- Sun/Thu notifications only fire if a GroceryList exists.
- Budget status displays after planning; threshold editable in the week.

Test plan
- Unit: rule application; grocery generation; budget thresholds; notification scheduling.
- UI: reassign an owner and observe downstream; finalize → list created; edit list; see nudges.
- Manual: toggle flags off/on, verify safe degradation.

Data & migration
- Add OwnershipRules snapshot to WeeklyPlan.
- Introduce GroceryList and line items; backfill none for prior weeks.

Analytics (opt-in)
- `meals.finalized`, `grocery.generated`, `grocery.nudge_shown`, `budget.status_set`.

Rollback
- Disable flags to fall back to Stage 0 meal behavior.

Go/No-Go checklist
- [ ] Rules assign correctly in a fresh week and after edits.
- [ ] GroceryList appears on finalize; Sun/Thu nudge behavior proven.
- [ ] Budget status visible and accurate.
- [ ] Tests and accessibility pass.

---

## Stage 2 — Chores & Gentle Reminders

Goal
- Introduce chore scheduling with clear ownership and light reminders.

Scope
- Chore model: title, owner, frequency, next due window, status.
- Frequency presets: weekly, monthly, every other week, first/third Saturday.
- Monthly Chore Review to rebalance.
- Local reminders on due day and Add-to-Calendar export.

Non-goals
- Cross-device sync; Google/Apple Calendar write-through.

Feature flags
- `ff.chores.core`
- `ff.chores.monthlyReview`
- `ff.notifications.chores`
- `ff.calendar.export`

Acceptance criteria
- Creating a chore schedules the next occurrence per preset.
- Completing a chore advances next due date correctly.
- Monthly review lists upcoming chores; bulk reassignment works.
- Export creates a correct .ics/EventKit entry.

Test plan
- Unit: recurrence calculations; ownership changes; completion roll-forward.
- UI: create → complete → verify next occurrence; monthly review reassignment; export.
- Manual: timezone sanity check for due windows.

Data & migration
- New Chore entity and Recurrence struct; no backfill required.

Analytics (opt-in)
- `chores.created`, `chores.completed`, `chores.review_completed`.

Rollback
- Disable `ff.chores.core`; keep data intact but hide UI.

Go/No-Go checklist
- [ ] All recurrence presets verified with sample dates.
- [ ] Monthly review flow demonstrably reassigns.
- [ ] Export artifacts attached.
- [ ] Tests and accessibility pass.

---

## Stage 3 — Events & Calendar Hub (Outings, Date Night Rotation, Micro-Moments)

Goal
- Plan time together with the same ease as meals.

Scope
- Event types: Family Outing, Date Night (biweekly default), Micro-Moment.
- Planner rotation for Date Night (alternates responsibility).
- Optional Project stub with checklisted steps (step scheduling).
- Calendar Hub: one place to view and export week events.

Non-goals
- Full project management; external calendar write.

Feature flags
- `ff.events.core`
- `ff.events.dateNightRotation`
- `ff.calendar.hub`
- `ff.projects.steps` (optional)

Acceptance criteria
- Creating events shows them in week view and Hub.
- Biweekly Date Night is pre-suggested; “planner” alternates on creation.
- Project steps schedule like events and sync status on completion.
- Export works for events and steps.

Test plan
- Unit: rotation logic; event/step linkage; hub aggregation.
- UI: create event → see in Hub → export; verify rotation; schedule/complete a step.
- Manual: edge cases (skipped week, holiday).

Data & migration
- New Event entity; optional Project/Step types.

Analytics (opt-in)
- `events.created`, `events.exported`, `events.rotation_applied`.

Rollback
- Disable `ff.events.core` to hide feature; data remains.

Go/No-Go checklist
- [ ] Rotation alternates across ≥4 created Date Nights.
- [ ] Hub lists all items for the week.
- [ ] Exports verified.
- [ ] Tests and accessibility pass.

---

## Stage 4 — Rituals: Weekly Connection, Daily Preview, Hard Topics

Goal
- Add the human rhythm that reduces mental load.

Scope
- Weekly Connection flow: appreciations, quick review, week decisions.
- WeeklyNotes tied to WeeklyPlan.
- Daily Preview card (evening) with one-tap reassign/defer.
- Hard Topics with context (walk/coffee), soft schedule, snooze.

Non-goals
- Cloud sync; push notifications.

Feature flags
- `ff.rituals.weeklyConnection`
- `ff.rituals.dailyPreview`
- `ff.rituals.hardTopics`

Acceptance criteria
- Completing Weekly Connection persists WeeklyNotes and updates the plan.
- Daily Preview appears 6–8pm (configurable) when tomorrow has items; actions update underlying records.
- Hard Topics can be soft-scheduled and snoozed; never silently disappear.

Test plan
- Unit: persistence; snooze/defer transitions; preview query for “tomorrow”.
- UI: run Weekly Connection; trigger a preview; create and snooze a Hard Topic.
- Manual: clock/timezone sanity.

Data & migration
- Add WeeklyNotes and HardTopic types.

Analytics (opt-in)
- `ritual.weekly.completed`, `preview.opened`, `hardtopic.created`.

Rollback
- Disable individual flags to hide flows; preserve data.

Go/No-Go checklist
- [ ] Demo shows Weekly Connection end-to-end.
- [ ] Daily Preview actionable; Hard Topic snooze/resolution verified.
- [ ] Tests and accessibility pass.

---

## Stage 5 — Quarterly Review & Insights

Goal
- Reflect and course-correct with light metrics and carry-forwards.

Scope
- Quarterly Review template: guided questions.
- Insights: planned vs completed; fairness split by domain and overall.
- Carry-forward actions pinned into the next quarter’s first Weekly Connection.

Non-goals
- Advanced analytics; external dashboards.

Feature flags
- `ff.quarterly.review`
- `ff.quarterly.insights`

Acceptance criteria
- Completing the review stores responses and shows computed insights from historical weeks.
- Fairness indicator displays neutral percentage and trend.
- Selected actions appear in the next quarter’s Weekly Connection.

Test plan
- Unit: aggregation math; date windows; fairness computation.
- UI: create dummy history → run review → verify insights and carry-forwards.
- Manual: boundary windows (quarter roll).

Data & migration
- QuarterlyReview entity; lightweight Insights cache (optional).

Analytics (opt-in)
- `quarterly.completed`, `insights.viewed`.

Rollback
- Disable flags; hide UI; keep review data intact.

Go/No-Go checklist
- [ ] Insights match prepared historical dataset.
- [ ] Carry-forwards appear in next quarter.
- [ ] Tests and accessibility pass.

---

## Stage 6 — Collaboration & Sync Polish (CloudKit/SwiftData Sharing)

Goal
- Make it truly collaborative across devices and partners.

Scope
- Family sharing via CloudKit-backed container.
- Merge policy: last writer wins with human-readable merge prompts for WeeklyPlan artifacts.
- Optional push for major lifecycle events (finalized plan, new Hard Topic).

Non-goals
- Cross-platform; complex roles/permissions.

Feature flags
- `ff.sync.sharing`
- `ff.notifications.push` (optional)

Acceptance criteria
- Two devices in same Family see changes converge within seconds.
- Conflicts never drop data; prompt appears and creates an audit trail entry.
- Offline edit → reconnect merges as specified.

Test plan
- Multi-device manual: airplane mode edits on both devices → reconnect.
- Unit: sync adapters; merge policies; audit metadata.
- UI: conflict prompt flows.

Data & migration
- Introduce audit metadata (lastModified, lastModifiedBy).

Security & privacy
- Explicit opt-in to share; clear “Stop Sharing” path.

Rollback
- Disable `ff.sync.sharing`; devices fall back to local-first.

Go/No-Go checklist
- [ ] Convergence proven with video from two devices.
- [ ] Conflict-merge prompt demoed; audit entries visible.
- [ ] Tests and accessibility pass.

---

## Stage templates

Use this template when proposing changes inside a stage:
- Change summary
- Acceptance criteria delta
- New tests
- Migration impact
- Flags to touch
- Rollback strategy
- Docs to update

---

## Release protocol (per stage)

1. Create branch `release/stage-X`.
2. Land changes behind flags; raise PR with:
   - Demo video, test outputs, accessibility screenshots, migration notes.
   - Updated README sections, CHANGELOG, and this file.
3. QA executes E2E_SUITES for the stage.
4. Go/No-Go review; if Go:
   - Merge; tag `vX.Y.0`.
   - Update ROADMAP (move Next → Now for the following stage).
5. If No-Go:
   - Keep branch open; fix only Go blockers; do not add scope.

---

## Known risks and guardrails

- Recurrence/math bugs: keep recurrence utilities pure and unit-tested with boundary cases.
- Notification fatigue: default opt-in and offer batched Daily Preview; never duplicate nudges.
- Sync conflicts (Stage 6): treat WeeklyPlan as the orchestrator; prefer prompting over silent merges.
- Performance drift: run perf tests as part of the PR checklist; fail CI if gates regress.

---

End of file.
