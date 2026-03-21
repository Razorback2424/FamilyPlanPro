# VISION.md
Family Plan Pro — Product Vision (v1.0)

This document defines what Family Plan Pro is, why it exists, and the end-state experience we are building. It is stable across releases and should only be amended with a brief “Vision Changelog” at the end of this file.

---

## Purpose and value
Family Plan Pro lowers household mental load by turning a few short rituals into a shared weekly plan that both partners trust. The app focuses on meals, chores, time together, and tough topics—kept predictable, fair, and reversible.

---

## Product principles
1. Ritual over features. A few consistent flows beat a large surface area.
2. Gentle by default. Language and UI avoid blame; actions feel reversible.
3. One source of truth per week. A WeeklyPlan orchestrates meals, chores, events, and notes.
4. Predictable cadence. Sunday planning, Sun/Thu grocery runs, daily preview, monthly chore review, quarterly reflection.
5. Fairness is visible. Load balance is easy to see and rebalance without drama.
6. Private by design. Local-first data with explicit sharing; minimal data collection.

---

## Users and problems
Primary users are two adults running a household. Typical pain points:
- Decision fatigue around meals and groceries.
- Invisible labor on chores and reminders.
- Drifting on time together and shared projects.
- Tough conversations that get avoided or happen at bad times.
- Lack of shared context day to day and across quarters.

---

## Pillars and core experiences
1) Weekly Connection (Sunday)
A 5–10 minute guided flow that captures appreciations, reviews last week, and sets this week’s decisions across meals, chores, events, budget, and hard topics.
- Artifacts: WeeklyNotes, WeeklyPlan
- Outcome: Clear plan; visible ownership and cadence for the week.

2) Meals with Ownership and Grocery Rhythm
Assign days to each partner, mark Friday as “simple,” generate one grocery list from finalized meals, nudge Sun/Thu grocery runs, and surface a simple budget check.
- Artifacts: MealSlots, MealSuggestions, GroceryList, BudgetStatus
- Outcome: Predictable dinner responsibilities, on-budget groceries, fewer back-and-forths.

3) Household Chores with Gentle Reminders
A chore model with frequency, owner, due window, and status. A monthly review to rebalance and export to calendar.
- Artifacts: Chore, Recurrence rules
- Outcome: No one carries the list in their head; changes are easy and visible.

4) Intentional Time Together
Events for Family Outings, Date Nights (alternating planner), and Micro-Moments. A Calendar Hub shows the week at a glance and exports items.
- Artifacts: Event, optional Project with Steps
- Outcome: Time together appears by default, not as an afterthought.

5) Daily Preview
A brief evening card that shows tomorrow’s meals, chores, and events with one-tap reassign or defer.
- Artifacts: Preview snapshot; reassignment actions
- Outcome: Tomorrow feels doable; small adjustments happen without friction.

6) Hard Topics (Soft Scheduling)
Capture sensitive topics, attach a preferred context (walk, coffee), softly schedule and snooze.
- Artifacts: HardTopic, SoftSchedule
- Outcome: Heavy conversations happen when both have bandwidth.

7) Quarterly Review and Insights
A quarterly reflection that surfaces simple insights (planned vs completed, fairness split) and carry-forward focus items.
- Artifacts: QuarterlyReview, Fairness metrics
- Outcome: The household adapts intentionally; wins are recognized.

Non-goals (v1): full budgeting, grocery delivery integrations, deep project management, social/community features.

---

## Information architecture (conceptual)
- Family: name, sharing, defaults (ownership rules, grocery cadence, notifications).
- User: display name, contact options, calendar preferences.
- WeeklyPlan: one per week; status; snapshot of rules; budget target; links to Meals/Chores/Events/Notes.
- WeeklyNotes: appreciations, decisions, carry-forwards.
- Meals: MealSlots (date, owner, “simple Friday”), MealSuggestions, finalized selection.
- GroceryList: auto-generated items, manual edits, budget status.
- Chore: title, owner, frequency, next due window, status.
- Event: type (Outing, Date Night, Micro-Moment; optional ProjectStep), planner/owner, schedule.
- HardTopic: title, context, soft schedule, deferrals, resolution notes.
- QuarterlyReview: responses, insights, carry-forwards.

---

## Cadences and notifications
- Weekly Connection: prompt on Sunday morning; snooze available.
- Grocery cadence: Sun and Thu reminders when a GroceryList exists.
- Daily Preview: evening reminder (configurable window) when tomorrow has items.
- Monthly Chore Review: first weekend of the month, optional.
- Quarterly Review: every 13 weeks after first Weekly Connection completion.

---

## Fairness model (simple and transparent)
- Split index by domain and overall, based on planned responsibility and completions.
- Display as a neutral percentage and trend (e.g., “52/48 this quarter”).
- Provide one-tap rebalance suggestions during Weekly Connection and monthly review.
- Never frame as judgment; present as shared visibility.

---

## Copy and tone
- Warm, brief, and nonjudgmental.
- Offer deferrals without penalty; celebrate completions and appreciations.
- Avoid blame on missed items; always present the next best step.

---

## Accessibility baseline
- VoiceOver labels and readable grouping for all controls.
- Dynamic Type and minimum touch targets.
- Color contrast AA throughout; state is legible without color.
- Motion subtle; no animation required to understand state.

---

## Privacy and security
- Local-first data; explicit opt-in Family sharing.
- Cloud sync via iCloud/CloudKit with clear “Stop Sharing.”
- No third-party trackers; privacy-preserving analytics are opt-in.
- Calendar export is user-initiated; background writes require explicit consent.

---

## Integrations (progressive)
- Phase 1: Local notifications and export via EventKit/ICS.
- Phase 2: Apple Calendar write-through (consent-gated).
- Phase 3: Google Calendar write-through (OAuth).
- Keep a provider abstraction for calendars to avoid lock-in.

---

## Analytics (privacy-preserving)
Events are counts/durations without content. Toggle is off by default.
- Weekly Connection completion rate.
- Grocery cadence adherence (Sun/Thu).
- Daily Preview engagement rate.
- Chores completion rate; Events scheduled per week.
- Fairness delta per quarter; consecutive weeks planned.
- Retention proxies from ritual completion streaks.

---

## Success metrics (12-week targets post-GA)
- Weekly Connection completion: 75%.
- Meal plans finalized per active week: 60%; grocery lists generated: 50%; Sun/Thu cadence: 40%.
- Two or more events planned per week by week 8 for retained households.
- Reported mental load reduction: 10-point (self-report) by week 12.
- Fairness drift ≤ 55/45 in ≥ 70% of active households by quarter end.

---

## Acceptance criteria per pillar (design-level, code-free)
Weekly Connection
- Start, skip sections, and finish in ≤10 minutes.
- Produces WeeklyNotes and updates WeeklyPlan artifacts.
- Reopen shows last saved state; reversible until finalize.

Meals & Grocery
- Ownership rules assign days automatically; Friday labeled “simple.”
- Finalizing creates one GroceryList with editable items grouped by day.
- Sun/Thu nudges only when a GroceryList exists; budget status shows under/on/over.

Chores
- Frequency presets: weekly, monthly, every other week, first/third Saturday.
- Completing advances next due window; monthly review supports bulk reassignment.
- Export to calendar produces correct entries.

Events & Calendar Hub
- Event types create with sensible defaults; Date Night alternates planner automatically.
- Hub shows all week items; export works for events and steps.
- Optional Project Steps schedule like events; completion syncs status.

Daily Preview
- Appears in evening if tomorrow has items; supports reassign/defer.
- Actions immediately update underlying records.

Hard Topics
- New entries capture preferred context and soft schedule; snooze never loses visibility.
- Resolution notes and archive state available.

Quarterly Review
- Guided flow saves responses; insights compute from historical weeks.
- Carry-forwards appear in the next quarter’s first Weekly Connection.

---

## Quality bars (apply to every release)
- Cold start to Current Week ≤1s on modern devices (release build).
- Week view render ≤200ms with representative data volume.
- Undo/Cancel path for destructive actions within the current screen.
- Non-destructive migrations with verified upgrade paths.
- ≥80% unit coverage for cadence and rule engines; UI smoke tests for core flows.

---

## Technical approach (high level)
- SwiftUI for UI; SwiftData for local persistence.
- CloudKit for Family sharing; merge policy with human-readable prompts for WeeklyPlan artifacts; audit metadata retained.
- UNUserNotificationCenter for local notifications; EventKit for calendar export/write.
- Feature flags to stage pillars safely; flags documented per stage.

---

## Roadmap phases (summary)
See `STAGED_DELIVERY.md` for detailed scope, flags, tests, and go/no-go gates.
- Stage 0: Baseline stabilization.
- Stage 1: Meals to vision.
- Stage 2: Chores and gentle reminders.
- Stage 3: Events and Calendar Hub.
- Stage 4: Ritual flows (Weekly Connection, Daily Preview, Hard Topics).
- Stage 5: Quarterly Review and insights.
- Stage 6: Collaboration and sync polish.

---

## Design system notes
- Card-based sections with a single clear primary action.
- Summaries up top with progressive disclosure into details.
- Consistent iconography: ownership (avatar chips), state (due/complete/deferred).
- Color as accent; state understandable in monochrome.

---

## Risks and mitigations
- Recurrence math errors → Pure utilities with boundary unit tests; fixtures around DST/first-of-month rules.
- Notification fatigue → Respectful defaults, consolidated Daily Preview, never duplicate nudges.
- Sync distrust → Visible merge prompts, audit trail on conflicts, safe local-first mode.
- Performance drift → Performance gates in PR checklist; fail CI on regression.

---

## Open questions (pre-GA)
- Require both partners to opt-in for sharing, or allow one-sided planning with read-only until the second joins?
- Children/guest profiles in v1 or defer?
- Minimum iOS version target given SwiftData features?
- Apple Calendar write in v1 or export-only and add writes in a point release?

---

## Definition of “Vision complete”
- Each pillar has one end-to-end flow implemented, tested, and demoable without external services.
- All cadences work with notifications off; manual entry points exist.
- Data model supports migrations; calendar integrations are provider-abstracted.
- Empty states and copy complete across all new screens.

---

## Vision Changelog
- v1.0: Initial publication aligned to staged delivery v1.0.
