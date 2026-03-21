# DATA_MODEL.md
Family Plan Pro — Data Model (v1.0)

This document defines the canonical data model for the app. It specifies entities, fields, relationships, invariants, indexes, and lifecycle rules. Use this as the source of truth for persistence, migrations, and tests.

---

## Conventions

Identifiers and timestamps
- `id`: UUID (string). Generated via `UUIDFactory`.
- `createdAt`, `updatedAt`: Date (UTC).
- `deletedAt`: optional Date (soft delete).
- `lastModifiedBy`: optional User ID (introduced at Stage 6).
- Enforce monotonic `updatedAt`.

Common fields
- All persisted entities include: `id`, `createdAt`, `updatedAt`, `deletedAt?`.
- Stage 6 adds audit metadata to user-editable artifacts: `lastModified`, `lastModifiedBy`.

Naming and scope
- All records belong to exactly one `Family` (multi-tenant boundary).
- Time-based records store dates in local calendar semantics but persist as UTC ISO dates with timezone metadata where needed.

Privacy classes
- P0 Sensitive: WeeklyNotes, HardTopic (show minimal previews, guard in logs).
- P1 Personal: ownership assignments, chore owners.
- P2 Operational: computed insights, fairness metrics.
- P3 System: migration logs, feature flags.

---

## Entity catalog (by Stage)

| Entity               | Purpose                                              | Stage |
|----------------------|------------------------------------------------------|-------|
| Family               | Tenant boundary, shared settings                     | 0     |
| UserProfile          | Household member metadata                            | 0     |
| WeeklyPlan           | Orchestrator for a given ISO week                    | 0     |
| OwnershipRulesSnap   | Snapshot of meal ownership rules per week            | 1     |
| MealSlot             | Planned meal slot (date, owner, tags)                | 0/1   |
| MealSuggestion       | Candidate meals during Suggest/Review                | 0     |
| GroceryList          | Auto-generated list from finalized meals             | 1     |
| GroceryItem          | Line items within a GroceryList                      | 1     |
| BudgetStatus         | Weekly budget target and status                      | 1     |
| Chore                | Recurring household chore                            | 2     |
| Event                | Family Outing / Date Night / Micro-Moment            | 3     |
| Project              | Optional container for step-based work               | 3*    |
| ProjectStep          | Schedulable step linked to a Project                 | 3*    |
| WeeklyNotes          | Appreciations and decisions captured on Sunday       | 4     |
| HardTopic            | Sensitive topic with soft scheduling/snooze          | 4     |
| DailyPreviewCache    | Derived snapshot for “tomorrow”                      | 4     |
| QuarterlyReview      | Reflection responses                                 | 5     |
| InsightSnapshot      | Cached aggregates for fairness/throughput            | 5     |
| AuditMetadata        | Conflict and merge trail (added to key entities)     | 6     |

\* Optional in 3.0; can land in 3.1 without affecting other entities.

---

## Core entities and fields

### Family
Purpose: Tenant; groups all data and governs sharing.
Fields
- `id`, `createdAt`, `updatedAt`, `deletedAt?`
- `name`: String
- `calendarDefaults`: { groceryNudgeTimes: { sun, thu }, previewWindow: { start, end } }
- `featureFlags`: Map<String, Bool> (effective defaults; non-remote in v1)
Invariants
- Deleting a Family cascades soft-deletes to all dependents.
Indexes
- `name` (non-unique, optional)
Lifecycle
- Created at first run; sharing introduced at Stage 6.

### UserProfile
Purpose: Member of a Family.
Fields
- `id`, `createdAt`, `updatedAt`, `deletedAt?`
- `familyId`: Family.id
- `displayName`: String
- `avatarColor`: String (token)
- `isPrimary`: Bool
- `calendarWriteConsent`: Bool (default false)
Indexes
- `familyId`
Invariants
- At least one `isPrimary == true` per Family.

### WeeklyPlan
Purpose: Single source of truth for a calendar week.
Fields
- `id`, `createdAt`, `updatedAt`, `deletedAt?`
- `familyId`: Family.id
- `year`: Int (ISO-8601)
- `isoWeek`: Int (1–53)
- `status`: Enum { suggestion, review, finalized }
- `ownershipRulesSnapId?`: OwnershipRulesSnap.id
- `budgetTargetCents?`: Int
- `budgetStatus`: Enum { unset, under, on, over }
- `notesId?`: WeeklyNotes.id
Derived
- `weekStartDate`, `weekEndDate` (computed from ISO week in Family timezone)
Constraints
- Unique compound key: (familyId, year, isoWeek)
- Exactly one active WeeklyPlan per (family, week).
Indexes
- `(familyId, year, isoWeek)` unique
Lifecycle
- Autocreated at app entry if missing; reversible state transitions until finalized.

### OwnershipRulesSnap
Purpose: Immutable snapshot of meal ownership for a specific week.
Fields
- `id`, `createdAt`, `updatedAt`, `deletedAt?`
- `familyId`: Family.id
- `weeklyPlanId`: WeeklyPlan.id
- `rules`: Map<Weekday, UserProfile.id> (Mon–Sun)
- `fridaySimple`: Bool (default true)
Invariants
- Once referenced by a WeeklyPlan, treated as immutable (update by replace).
Indexes
- `weeklyPlanId` unique

### MealSlot
Purpose: Planned meal slot per day (breakfast/lunch/dinner optional; v1 assumes dinner).
Fields
- `id`, `createdAt`, `updatedAt`, `deletedAt?`
- `familyId`, `weeklyPlanId`
- `date`: Date (local day)
- `ownerId`: UserProfile.id (from OwnershipRulesSnap by default)
- `label`: Enum { dinner } (extensible later)
- `isSimple`: Bool (Friday rule)
- `finalSelection?`: String (human-friendly name or reference to cookbook URL in future)
Indexes
- `weeklyPlanId`, `(weeklyPlanId, date)`
Invariants
- `ownerId` must be a member of the same Family.
- Friday → `isSimple == true` by default.

### MealSuggestion
Purpose: Candidate meal values during Suggest/Review.
Fields
- `id`, `createdAt`, `updatedAt`, `deletedAt?`
- `familyId`, `weeklyPlanId`, `mealSlotId`
- `title`: String
- `notes?`: String
- `proposedBy`: UserProfile.id
Indexes
- `mealSlotId`
Invariants
- Deleted or archived when WeeklyPlan transitions to Finalized.

### GroceryList
Purpose: Single list generated from finalized meals.
Fields
- `id`, `createdAt`, `updatedAt`, `deletedAt?`
- `familyId`, `weeklyPlanId`
- `status`: Enum { draft, ready, ordered }
- `budgetObservedCents?`: Int
Indexes
- `weeklyPlanId` unique

### GroceryItem
Purpose: Line item within a GroceryList.
Fields
- `id`, `createdAt`, `updatedAt`, `deletedAt?`
- `groceryListId`
- `dayRef?`: Date (if tied to a meal)
- `name`: String
- `qty`: String
- `section`: Enum { produce, dairy, meat, pantry, bakery, frozen, other }
- `checked`: Bool
Indexes
- `groceryListId`, `section`

### BudgetStatus (folded into WeeklyPlan)
Purpose: Lightweight budget signal.
Fields
- `budgetTargetCents?`, `budgetObservedCents?` (via GroceryList), `budgetStatus` (derived).
Derivation
- under/on/over based on configured tolerance (e.g., ±5%).

### Chore
Purpose: Recurring household task.
Fields
- `id`, `createdAt`, `updatedAt`, `deletedAt?`
- `familyId`
- `title`: String
- `ownerId`: UserProfile.id
- `frequency`: Enum { weekly, monthly, biweekly, firstSaturday, thirdSaturday, customRRULE }
- `rrule?`: String (for custom)
- `nextDueStart`: Date (window start)
- `nextDueEnd`: Date (window end)
- `status`: Enum { scheduled, done, skipped }
Indexes
- `familyId`, `(ownerId, nextDueStart)`
Invariants
- Completing advances next window based on frequency.
- Monthly Review can reassign `ownerId` for subsequent windows.

### Event
Purpose: Planned time together.
Fields
- `id`, `createdAt`, `updatedAt`, `deletedAt?`
- `familyId`, `weeklyPlanId?` (week association optional)
- `type`: Enum { outing, dateNight, microMoment, projectStep }
- `plannerId`: UserProfile.id (rotates for dateNight)
- `start`: DateTime, `end?`: DateTime
- `location?`: String
- `notes?`: String
- `calendarExternalId?`: String (EventKit/Google pointer)
Indexes
- `familyId`, `(familyId, start)`
Invariants
- Date Night rotation rule sets `plannerId` on creation unless overridden.

### Project (optional 3.x)
Purpose: Simple grouping for step-based efforts.
Fields
- `id`, `createdAt`, `updatedAt`, `deletedAt?`
- `familyId`, `title`, `status`: { active, paused, done }
Indexes
- `familyId`

### ProjectStep (optional 3.x)
Purpose: Schedulable step linked to a project.
Fields
- `id`, `createdAt`, `updatedAt`, `deletedAt?`
- `projectId`, `title`, `status`: { pending, scheduled, done }
- `eventId?`: Event.id (if scheduled)
Indexes
- `projectId`

### WeeklyNotes
Purpose: Output of Weekly Connection.
Fields
- `id`, `createdAt`, `updatedAt`, `deletedAt?`
- `familyId`, `weeklyPlanId`
- `appreciations`: [String]
- `decisions`: [String]
- `carryForwards`: [String]
Privacy
- P0 Sensitive

### HardTopic
Purpose: Sensitive topics with soft scheduling.
Fields
- `id`, `createdAt`, `updatedAt`, `deletedAt?`
- `familyId`
- `title`: String
- `preferredContext`: Enum { walk, coffee, eveningChat, drive, other }
- `softScheduleAt?`: DateTime
- `snoozedUntil?`: DateTime
- `status`: Enum { open, snoozed, scheduled, discussed, archived }
- `resolutionNotes?`: String
Privacy
- P0 Sensitive
Invariants
- Never auto-delete; archive explicitly.

### DailyPreviewCache
Purpose: Derived snapshot for “tomorrow”.
Fields
- `id`, `createdAt`, `updatedAt`
- `familyId`, `date` (snapshot date)
- `items`: JSON blob { meals, chores, events summary }
Notes
- Ephemeral; safe to regenerate; exclude from CloudKit sync if size is large.

### QuarterlyReview
Purpose: Reflection responses.
Fields
- `id`, `createdAt`, `updatedAt`, `deletedAt?`
- `familyId`
- `quarterKey`: String (e.g., `2026-Q1`)
- `responses`: Map<PromptId, String>
Indexes
- `(familyId, quarterKey)` unique

### InsightSnapshot
Purpose: Cached aggregates for performance and fairness.
Fields
- `id`, `createdAt`, `updatedAt`
- `familyId`, `window`: { type: week|quarter, key: String }
- `metrics`: {
  plannedMeals: Int, completedMeals: Int,
  choresPlanned: Int, choresDone: Int,
  eventsPlanned: Int,
  fairnessMealsPct: { a: Int, b: Int },
  fairnessChoresPct: { a: Int, b: Int },
  fairnessEventsPct: { a: Int, b: Int }
}
Notes
- Regenerated on demand or nightly; safe to purge/rebuild.

### AuditMetadata (Stage 6 augmentation)
Purpose: Human-readable conflict resolution trail.
Augments entities: WeeklyPlan, MealSlot, Chore, Event, WeeklyNotes, HardTopic
Fields
- `lastModified`: Date
- `lastModifiedBy`: UserProfile.id
- `conflictLog`: [ { timestamp, entityId, field, theirs, ours, resolution } ]

---

## Relationships

- Family 1—N UserProfile
- Family 1—N WeeklyPlan
- WeeklyPlan 1—1 OwnershipRulesSnap
- WeeklyPlan 1—N MealSlot
- MealSlot 1—N MealSuggestion
- WeeklyPlan 1—1 GroceryList
- GroceryList 1—N GroceryItem
- WeeklyPlan 1—1 WeeklyNotes
- Family 1—N Chore
- Family 1—N Event (optional WeeklyPlan linkage)
- Project 1—N ProjectStep (optional Event linkage)
- Family 1—N HardTopic
- Family 1—N QuarterlyReview
- Family 1—N InsightSnapshot

Constraints and guards
- All child entities must share the same `familyId` as their parent.
- WeeklyPlan uniqueness by `(familyId, year, isoWeek)`.

---

## Derivations and computations

- Meal ownership: default from OwnershipRulesSnap; user edits allowed per slot.
- Friday simple: `isSimple == true` for Friday’s slots; users may override, but UI should prompt.
- Grocery list generation: collect ingredients from `finalSelection` (v1 uses plain names/notes), group by day/section.
- Budget status: compare `budgetObservedCents` (entered) vs `budgetTargetCents`.
- Chore recurrence: deterministic next window from `frequency`/`rrule`.
- Date Night rotation: alternate `plannerId` by last `dateNight` created for the Family.
- Daily Preview: query tomorrow across MealSlot, Chore (due), Event (start within window).
- Fairness: compute % split for owner assignments (planned) and completions (done) per domain.

---

## Indexing strategy

Must-have indexes
- `WeeklyPlan(familyId, year, isoWeek)` unique
- `MealSlot(weeklyPlanId, date)`
- `Chore(ownerId, nextDueStart)` and `Chore(familyId)`
- `Event(familyId, start)`
- `GroceryList(weeklyPlanId)` unique
- `WeeklyNotes(weeklyPlanId)` unique
- `QuarterlyReview(familyId, quarterKey)` unique

Nice-to-have
- `HardTopic(familyId, status)`
- `InsightSnapshot(familyId, window.key)`

---

## Lifecycle and invariants

Creation
- New week: create `WeeklyPlan` + `OwnershipRulesSnap` + seed `MealSlot` for each day.
- GroceryList is created on finalize; regenerating replaces items but preserves manual edits via merge rules (Stage 1.1).

State transitions
- WeeklyPlan: `suggestion ↔ review → finalized` (only deepen to `finalized`; allow revert to `suggestion` until groceries generated).
- Chore: `scheduled → done/skipped → scheduled (advanced window)`.
- HardTopic: `open ↔ snoozed ↔ scheduled → discussed → archived`.

Deletion
- Soft-delete only; physical purge via maintenance task.
- Cascade soft-delete on parent delete (Family, WeeklyPlan).

Consistency checks (nightly or on open)
- Ensure single WeeklyPlan per week.
- Heal orphaned children by soft-deleting or re-linking (log in AuditMetadata).

---

## Access patterns (per feature)

Meals
- Query `WeeklyPlan` for current week → fetch `MealSlot` by date → fetch `MealSuggestion` during Suggest/Review.
- On finalize → create/refresh `GroceryList` + items.

Chores
- Query `Chore` by `ownerId` and `nextDueStart in [today, +7d]`.
- Monthly Review: `Chore` by Family, next window in next 30 days.

Events
- Query `Event` by Family for week start/end.
- Calendar Hub aggregates `MealSlot`, `Chore (due)`, and `Event`.

Rituals
- Weekly Connection upserts `WeeklyNotes`, updates `WeeklyPlan` fields.
- Daily Preview reads derived `DailyPreviewCache` (regenerate if stale).

Quarterly
- `QuarterlyReview` by `(familyId, quarterKey)`; `InsightSnapshot` window `quarter`.

---

## Migration guidance (per Stage)

Stage 0 → 1
- Add OwnershipRulesSnap; backfill from Family defaults (Mon/Wed/Sat vs Tue/Thu/Sun; Friday simple).
- Add GroceryList/GroceryItem (none created until first finalize).
- Add `budgetTargetCents`, `budgetStatus` to WeeklyPlan (default `unset`).

Stage 1 → 2
- Add Chore with migration creating an empty set. No backfill.

Stage 2 → 3
- Add Event; optional Project/ProjectStep. No required backfill.

Stage 3 → 4
- Add WeeklyNotes, HardTopic, DailyPreviewCache (ephemeral).
- Do not backfill WeeklyNotes; create on first Weekly Connection.

Stage 4 → 5
- Add QuarterlyReview and InsightSnapshot. Compute first insights lazily.

Stage 5 → 6
- Add audit fields to user-editable entities; initialize `lastModified` from `updatedAt`.

Migration rules
- Never drop fields without a safe fallback.
- Write idempotent transforms; log a migration record with counts changed.

---

## Seed data (Demo)

- Two UserProfiles (A/B), distinct avatar colors.
- Current `WeeklyPlan` with OwnershipRulesSnap (Mon/Wed/Sat → A; Tue/Thu/Sun → B; Friday simple).
- Seven `MealSlot` with a mix of suggestions.
- `Chore` examples: Weekly Trash (A), Bathrooms Monthly (B), Lawn Biweekly (A).
- Events: One Date Night in two weeks (rotation demo), one Outing this week.
- One HardTopic with `preferredContext = walk` and `status = open`.

---

## Data retention and purge

- Soft-deleted records are eligible for purge after 90 days.
- Derived caches (DailyPreviewCache, InsightSnapshot) can be regenerated; purge freely.
- When leaving a Family or stopping sharing, keep a local export option for the user.

---

## Validation and testing

- Unit tests for:
  - WeeklyPlan uniqueness and lifecycle transitions.
  - Ownership defaulting and Friday simple logic.
  - Grocery generation and budget derivation.
  - Chore recurrence math (DST boundaries, first/third Saturday).
  - Date Night rotation across gaps.
  - HardTopic snooze windows and terminal states.
  - Insight aggregation windows (week/quarter).

- Fixtures:
  - Edge weeks (Week 1/53, year boundaries).
  - DST switch weeks.
  - Mixed-owner weeks for fairness calculations.

---

End of file.
