# STATE_MACHINES.md
Family Plan Pro — State Machines (v1.0)

This document defines the user-visible flows as finite state machines (FSMs). It specifies states, transitions, guards, side effects, undo rules, and persistence touch points so engineering, QA, and Codex agents can reason deterministically. No code; contracts only.

Contents
1. WeeklyPlan lifecycle
2. Meal planning selection flow
3. Grocery cadence (Sun/Thu nudges)
4. Chore recurrence
5. Events & Date Night rotation
6. Weekly Connection wizard
7. Daily Preview
8. Hard Topics (soft scheduling)
9. Quarterly Review
10. Conflict merge prompts (Stage 6)

Conventions
- Intent: a user or system action that requests a transition (e.g., “FinalizeWeek”).
- Guard: a condition that must be true for the transition to occur.
- Side effect: work triggered on transition (e.g., generate grocery list).
- Persist: fields/entities that must be updated transactionally.
- Telemetry: privacy-preserving event(s) to record if analytics is enabled.

---

1) WeeklyPlan lifecycle

Goal
One authoritative state per week that orchestrates downstream behavior.

States
- suggestion
- review
- finalized

Intents
- StartReview
- FinalizeWeek
- ReopenToSuggestion (reversible until certain side effects exist; see guards)

Transitions
- suggestion → review on StartReview
- review → suggestion on ReopenToSuggestion
- review → finalized on FinalizeWeek
- finalized → suggestion on ReopenToSuggestion (guarded; see below)

Guards
- StartReview: Current Week exists; at least one MealSlot present.
- FinalizeWeek: No blocking validation failures. Minimum viable rule set:
  - All 7 MealSlots have a finalSelection OR an explicit “skip” flag.
  - Ownership assigned for each slot.
- ReopenToSuggestion:
  - If a GroceryList does not exist OR user confirms discarding/re-generating it later.
  - If calendar exports were created, prompt that future changes will not edit past exports.

Side effects
- On FinalizeWeek:
  - Generate GroceryList (status=draft) and GroceryItems.
  - Compute budget status (under/on/over) if target set.
  - Schedule Sun/Thu nudges (see §3).
  - Telemetry: meals.finalized, grocery.generated.
- On ReopenToSuggestion:
  - Optionally delete or mark GroceryList as stale (implementation choice); never silently mismatch.

Persist
- WeeklyPlan.status
- WeeklyPlan.notesId? (if set via Weekly Connection)
- GroceryList + GroceryItems (create/replace)
- Budget fields on WeeklyPlan
- Audit metadata on affected entities (Stage 6)

Undo rules
- Any state change has an immediate “Undo” within the same session. Reopen from finalized requires explicit confirmation if it discards downstream artifacts.

---

2) Meal planning selection flow

Goal
Move each MealSlot from undecided to a single final selection before finalize.

Per-slot states (conceptual)
- unselected (default)
- candidateSet (has ≥1 suggestion)
- selected (finalSelection chosen)
- skipped (explicitly empty for that day)

Intents
- AddSuggestion(mealSlotId, title, notes?)
- RemoveSuggestion(mealSlotId, suggestionId)
- PickFinalSelection(mealSlotId, suggestionId or free-text)
- MarkSkipped(mealSlotId)
- ClearFinalSelection(mealSlotId)

Transitions
- unselected → candidateSet on AddSuggestion
- candidateSet → selected on PickFinalSelection
- candidateSet → unselected when last suggestion removed and no finalSelection
- Any → skipped on MarkSkipped (mutually exclusive with selected)
- skipped → candidateSet or selected on new input
- selected → candidateSet on ClearFinalSelection

Guards
- Owner for the day exists; if not, block with “Assign owner first”.

Side effects
- On PickFinalSelection: clear “skipped” if set.
- On MarkSkipped: clear candidate suggestions from visible UI (retain for audit until week end if desired).

Persist
- MealSuggestion (create/delete)
- MealSlot.finalSelection
- MealSlot.ownerId (ensured)
- MealSlot.isSimple (pre-set on Friday; may be overridden by user)

Telemetry
- suggestion.added, suggestion.removed, meal.final_selected

Undo rules
- Last action per slot is undoable in place.

---

3) Grocery cadence (Sun/Thu nudges)

Goal
Only schedule nudges when a GroceryList exists and the week is in progress.

States
- idle (no list or out of window)
- scheduled (Sun and/or Thu notifications set)
- fired (notification delivered for that day)
- snoozed (user deferred for hours)

Intents
- EnableCadence(weekId)
- DisableCadence(weekId)
- SnoozeNudge(weekId, hours)
- FireNudge(weekId, day=Sun|Thu)

Transitions
- idle → scheduled on EnableCadence (guard: GroceryList exists)
- scheduled → fired on FireNudge at configured time window
- fired → scheduled automatically for remaining day (if Thu is pending)
- any → snoozed on SnoozeNudge
- snoozed → scheduled when snooze window elapses
- scheduled → idle on DisableCadence or when week closes

Guards
- Week is current; not in the past.
- Only schedule for days that remain in the current week.

Side effects
- Create deterministic local notification IDs (`grocery-<weekId>-sun|thu`).
- Respect user opt-in for notifications.

Persist
- None required beyond NotificationScheduler; optional shadow record of last-fired timestamp.

Telemetry
- grocery.nudge_shown, grocery.nudge_snoozed

Undo rules
- Snooze can be canceled by reopening the app and tapping “Send now”.

---

4) Chore recurrence

Goal
Track next due windows and status without drift.

States
- scheduled
- done
- skipped

Intents
- CompleteChore(choreId)
- SkipChore(choreId, reason?)
- ReassignChore(choreId, newOwnerId)
- AdvanceWindow(choreId) (system intent after done/skip)

Transitions
- scheduled → done on CompleteChore → scheduled on AdvanceWindow
- scheduled → skipped on SkipChore → scheduled on AdvanceWindow
- scheduled → scheduled on ReassignChore (no state change; affects next window assignment)

Guards
- ReassignChore cannot remove last owner; must remain within same Family.

Side effects
- On AdvanceWindow: compute nextDueStart/End from frequency preset or RRULE; clear status to scheduled.

Persist
- Chore.status
- Chore.nextDueStart/End
- Chore.ownerId (on reassignment)

Telemetry
- chores.completed, chores.skipped, chores.review_completed (from monthly review batch)

Undo rules
- Completing/skipping can be undone until the window advances.

---

5) Events & Date Night rotation

Goal
Plan time together with a predictable rotation for Date Night.

Event states
- draft (optional creation state)
- scheduled
- completed (implicit when end < now; no user action required)

Intents
- CreateEvent(type, start, end, plannerId?)
- UpdateEvent(eventId, …)
- ExportEvent(eventId)
- DeleteEvent(eventId)

Transitions
- draft → scheduled on CreateEvent
- scheduled → scheduled on UpdateEvent
- scheduled → implicit completed when end < now (no persistence change required)

Date Night rotation
- On CreateEvent(type=dateNight, plannerId is empty), set plannerId using:
  - If no prior dateNight: choose alternately from Family primaries A/B starting with A.
  - Else: set to “the other partner” from the last dateNight’s plannerId, regardless of gap length.
- Allow manual override at creation.

Guards
- Event within reasonable bounds (start < end; not > 1 day by default).

Side effects
- Calendar export triggers EventKit/ICS creation if user chooses.

Persist
- Event fields; optional calendarExternalId on export.

Telemetry
- events.created, events.exported, events.rotation_applied

Undo rules
- Delete can be undone until app session ends or until exported (then show “keep calendar entry?” prompt).

---

6) Weekly Connection wizard

Goal
Short ritual that records appreciations, reviews, and decisions.

States
- notStarted
- inProgress(step=1..N)
- completed

Core steps (default)
1. Appreciations
2. Review last week (carry-forwards)
3. Meals snapshot check
4. Chores snapshot check
5. Events snapshot check
6. Budget check (optional)
7. Hard Topics capture (optional)
8. Confirm & Save

Intents
- StartWeeklyConnection(weekId)
- NextStep(data)
- PreviousStep()
- SaveWeeklyConnection()

Transitions
- notStarted → inProgress on StartWeeklyConnection
- inProgress → inProgress on NextStep/PreviousStep
- inProgress → completed on SaveWeeklyConnection

Guards
- Week exists and is current.

Side effects
- Create/Update WeeklyNotes; propagate any toggles to WeeklyPlan (budget target, etc.).
- Do not change WeeklyPlan.status; this wizard is orthogonal.

Persist
- WeeklyNotes
- WeeklyPlan fields modified by decisions (e.g., budgetTargetCents)

Telemetry
- ritual.weekly.completed

Undo rules
- Reopen the wizard during the same week to edit WeeklyNotes; changes tracked via updatedAt.

---

7) Daily Preview

Goal
Provide an evening snapshot with one-tap actions for tomorrow.

States
- hidden (no items tomorrow or outside window)
- visible
- acted (user made at least one change)
- dismissed

Intents
- ShowPreview(date=today)
- ReassignItem(itemRef, newOwnerId)
- DeferItem(itemRef, toDate)
- DismissPreview()

Transitions
- hidden → visible on ShowPreview (guard: within evening window; tomorrow has items)
- visible → acted on first Reassign/Defer
- visible|acted → dismissed on DismissPreview or window end

Guards
- Respect notification and preview settings.

Side effects
- Apply changes to underlying entities (MealSlot.ownerId, Chore.ownerId/nextDue*, Event start).
- Do not prompt calendar updates automatically; show a banner if an exported event changed.

Persist
- Underlying entity changes only; preview itself is ephemeral (may use DailyPreviewCache).

Telemetry
- preview.opened

Undo rules
- Per-item “Undo” toast immediately after change; no batch undo.

---

8) Hard Topics (soft scheduling)

Goal
Create space for sensitive conversations without pressure.

States
- open
- snoozed
- scheduled
- discussed
- archived

Intents
- CreateHardTopic(title, preferredContext)
- SoftSchedule(topicId, datetime)
- SnoozeTopic(topicId, until)
- MarkDiscussed(topicId, notes?)
- ArchiveTopic(topicId)
- UnarchiveTopic(topicId)

Transitions
- open → scheduled on SoftSchedule
- open → snoozed on SnoozeTopic
- snoozed → open on snooze window end or explicit cancel
- scheduled → discussed on MarkDiscussed
- discussed → archived on ArchiveTopic
- archived → open on UnarchiveTopic

Guards
- None beyond basic validity. Never auto-delete.

Side effects
- Optional reminder creation near softScheduleAt; reminders are opt-in.

Persist
- HardTopic fields (status, softScheduleAt, snoozedUntil, resolutionNotes)

Telemetry
- hardtopic.created

Undo rules
- Archival can be undone; discussed can be edited for notes within the same day.

---

9) Quarterly Review

Goal
Capture reflections, compute insights, and pin carry-forwards.

States
- notStarted
- inProgress
- completed

Intents
- StartQuarterlyReview(quarterKey)
- SaveResponse(promptId, text)
- CompleteQuarterlyReview(selectedCarryForwards)

Transitions
- notStarted → inProgress on StartQuarterlyReview
- inProgress → completed on CompleteQuarterlyReview

Guards
- quarterKey is the current or most recent quarter; one review per quarter.

Side effects
- Compute InsightSnapshot for the quarter from historical weeks.
- Create carry-forward items linked to next quarter’s first Weekly Connection.

Persist
- QuarterlyReview, InsightSnapshot

Telemetry
- quarterly.completed, insights.viewed

Undo rules
- Reopen to edit responses until the next quarter begins; insights recomputed on save.

---

10) Conflict merge prompts (Stage 6)

Goal
Resolve concurrent edits across devices without silent data loss.

Detection states (per entity)
- clean (no conflict)
- conflicting (local vs remote diffs on protected fields)
- resolved (user chose a path; merges applied)

Intents
- DetectConflict(entityId, fields)
- ResolveKeepTheirs(entityId)
- ResolveKeepOurs(entityId)
- ResolveMergeSpecificFields(entityId, fieldMap)

Transitions
- clean → conflicting on DetectConflict
- conflicting → resolved on any Resolve*

Guards
- Only entities with “protected fields” require prompting: WeeklyPlan, MealSlot, Chore, Event, WeeklyNotes, HardTopic.

Side effects
- Write a conflictLog entry to AuditMetadata with resolution details.
- If calendar writes exist and Event fields changed, prompt to update external calendar.

Persist
- AuditMetadata.conflictLog append
- Entity fields according to choice

Telemetry
- merge.prompt_shown, merge.resolved

Undo rules
- A resolved merge cannot be auto-undone; user may manually revert fields with standard edit/undo affordances.

---

Test hooks (per FSM)
- Each transition exposes a deterministic “canTransition(from, intent) -> Bool” check for unit tests.
- Side effects are invoked through service protocols (NotificationScheduler, CalendarSink) so tests can assert calls without performing them.

Performance and accessibility
- No state transition may block the main thread with network or heavy persistence.
- Every wizard or prompt state includes accessible labels and a visible focus order.

End of file.
