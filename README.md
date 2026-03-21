# Family Plan Pro

A calm, weekly command center for running a home together. Ritual-first flows for meals, chores, time together, and tough topics—kept lightweight, fair, and reversible.

## Why this exists
Families don’t need more lists; they need a predictable rhythm. Family Plan Pro turns a few short rituals into a shared weekly plan you both trust, with visible fairness and gentle reminders.

## Core pillars (what this app will ship)
- Weekly Connection (Sunday) to set the week’s plan and note decisions.
- Meals with ownership rules, simple Fridays, grocery list, Sun/Thu cadence, budget check.
- Household chores with recurrence, monthly review, and light reminders.
- Intentional time together: outings, biweekly date nights with rotating planner, micro-moments.
- Daily Preview (evening) to reassign or defer tomorrow’s items quickly.
- Hard Topics with soft scheduling and snooze.
- Quarterly Review with simple insights and carry-forward focus items.

See: `VISION.md` for full detail.

---

## Quickstart (local development)

**Requirements**
- Xcode 15+ (Swift 5.9+) and iOS 17+ target (SwiftUI + SwiftData).
- macOS with developer tools installed.

**Run**
1. Open the Xcode project/workspace.
2. Select the app scheme → iPhone simulator (or device) → Run.
3. On first launch, choose “Load Demo Week” when prompted to seed sample data.

**Reset demo data**
- In-app: Settings → “Reset Demo” to clear and reseed a representative week.

---

## Repository layout (source of truth)

- `App/` — SwiftUI app, features by domain (`Meals/`, `Chores/`, `Events/`, `Rituals/`).
- `Data/` — SwiftData models, migrations, seeders.
- `Services/` — Notifications, Calendar export, Analytics (privacy-preserving).
- `Shared/` — UI components, design tokens, utilities.
- `Tests/` — Unit and UI tests grouped by domain and stage.
- `docs/` — Product and technical docs (vision, specs, data model, test strategy, etc.).
- `codex/` — Team config for the Codex app/CLI/IDE, skills, and automations.

Keep files small and feature-scoped. Each feature folder should contain View, ViewModel, and FeatureTests.

---

## Staged delivery (must-pass gates)

This repo advances only via completed stages. Treat the checkboxes below as the release bar for each stage.

- [x] **Stage 0 — Baseline stabilization**  
  Lock WeeklyPlan status machine; week auto-creation; clean CRUD; demo data reliable.  
  Exit criteria: All state transitions tested; Finalized summary read-only; app start <1s; week load <200ms.

- [ ] **Stage 1 — Meals to vision**  
  Ownership rules by day; “Simple Friday”; grocery list from finalized meals; Sun/Thu nudges; budget status.  
  Exit criteria: Rules apply on week start; list groups by day; nudges only if list exists; budget under/on/over visible.
  
Stage 0 approved complete by owner on 2026-02-02; verification evidence (tests/perf/accessibility) deferred.

- [ ] **Stage 2 — Chores & reminders**  
  Recurrence, owner, due window; monthly review; calendar export; local notifications.  
  Exit criteria: Next occurrences correct; monthly reassignment works; export yields correct calendar entries.

- [ ] **Stage 3 — Events & Calendar Hub**  
  Outings, Date Night rotation, micro-moments; optional project step scheduling; weekly hub + export.  
  Exit criteria: Biweekly date nights pre-suggested; rotation alternates planner; hub lists all items.

- [ ] **Stage 4 — Ritual flows**  
  Weekly Connection + WeeklyNotes; Daily Preview; Hard Topics with soft schedule and snooze.  
  Exit criteria: Notes persist; evening preview appears with actions; snooze/defer preserves visibility.

- [ ] **Stage 5 — Quarterly Review & insights**  
  Guided questions; fairness indicators; carry-forward items.  
  Exit criteria: Insights compute from historical weeks; carry-forward pins into next Weekly Connection.

- [ ] **Stage 6 — Collaboration & sync**  
  Family sharing via CloudKit; conflict handling; optional push notifications.  
  Exit criteria: Two devices converge within seconds; conflict merges never lose data; audit metadata retained.

See: `STAGED_DELIVERY.md` for per-stage acceptance tests and go/no-go checklists.

---

## How to work with Codex (agents as first-class contributors)

**Threads and projects**
- One Codex thread per feature/bug. Reference stage and domain in the title, e.g., `Stage1: Meals—Grocery List Generation`.
- Keep threads short-lived; close them when acceptance criteria pass.

**Parallel agents (worktrees)**
- Agents operate on isolated worktrees/branches to avoid conflicts.
- Human reviewer drives “diff review → merge” from the app’s review queue.

**Team configuration**
- `codex/TEAM_CONFIG.md` defines the default project mapping, repo root, and safe defaults.
- `codex/SECURITY_RULES.md` lists what Codex can run automatically (build/tests) vs what needs approval (networked commands).

**Personalities**
- Default to terse/pragmatic. Switch to conversational only for user-facing copy passes.
- Record the chosen personality in the thread with `/personality terse` or `/personality conversational`.

**Skills**
- Skills bundle instructions + scripts so agents can act consistently:
  - `skills/FIGMA_IMPLEMENT_DESIGNS.md` — Implement UI with visual parity.
  - `skills/TEST_RUNNER.md` — Run the correct unit/UI suites and attach artifacts.
  - `skills/RELEASE_BRIEFS.md` — Draft release notes from merged PRs and CHANGELOG entries.
- When starting a task, explicitly enable relevant skills or let Codex auto-select.

**Automations**
- Use sparingly; results go to a review queue:
  - `automations/DAILY_ISSUE_TRIAGE.md` — Labels/owners, never auto-close.
  - `automations/CI_FAILURE_DIGEST.md` — Summarize flaky tests and top failures.
  - `automations/QUARTERLY_INSIGHTS.md` — Prepare the quarterly snapshot.

---

## Testing strategy (what must always pass)

- Unit tests for rule engines and cadences (ownership, recurrence, budget thresholds).
- UI smoke tests for core rituals: Weekly Connection, Finalize Meals, Daily Preview.
- Coverage: ≥80% for new logic in each stage.
- Performance gates (simulator, release build): app start <1s; week load <200ms.
- Accessibility checks: VoiceOver labels present; Dynamic Type safe; contrast AA.

See: `docs/quality/TEST_STRATEGY.md` and `docs/quality/E2E_SUITES.md`.

---

## Data, privacy, and security

- Local-first with explicit Family sharing. No third-party trackers.
- Calendar export is user-initiated; background writes require explicit consent.
- Analytics are opt-in, privacy-preserving counts and durations—never content.

See: `docs/tech/PRIVACY_SECURITY.md`.

---

## Contribution norms

- Small PRs; one feature or bug per PR.
- Every PR must update one of: `CHANGELOG.md`, `STAGED_DELIVERY.md`, or a spec in `docs/`.
- Use the PR checklist (tests, screenshots, accessibility notes, migration impact).

See: `CONTRIBUTING.md` and `.github/PR_TEMPLATE.md`.

---

## Release checklist (always)

- All stage exit criteria satisfied.
- Migrations tested on a copy of last release’s data.
- Accessibility and performance gates pass.
- `CHANGELOG.md` updated; `ROADMAP.md` reflects what moved to “Now/Next/Later”.

See: `docs/quality/RELEASE_CHECKLIST.md`.

---

## Pointers

- Vision and scope: `VISION.md`
- Stage details and go/no-go: `STAGED_DELIVERY.md`
- Domain specs: `docs/product/MEALS_SPEC.md`, `CHORES_SPEC.md`, `EVENTS_SPEC.md`, `RITUALS_SPEC.md`
- Architecture and data: `docs/tech/ARCHITECTURE.md`, `DATA_MODEL.md`, `STATE_MACHINES.md`
- Codex enablement: `codex/README.md`, `TEAM_CONFIG.md`, `PARALLEL_AGENTS.md`, `SECURITY_RULES.md`

This README is the operational home page. If something changes, update this file in the same PR.
