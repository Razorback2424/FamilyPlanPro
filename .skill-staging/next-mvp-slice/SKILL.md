---
name: next-mvp-slice
description: Implement exactly one next unfinished vertical MVP slice in the Family Plan Pro or Family Rhythm SwiftUI + SwiftData app. Use when continuing repo-planned MVP development from AGENTS.md plus STAGED_DELIVERY.md, PLANS.md, or a similar plan artifact, and the goal is to ship one small local-first slice, verify it, and update the smallest relevant progress artifact without jumping ahead or introducing speculative abstractions.
---

# Next MVP Slice

Implement one next unfinished vertical slice and stop.

Use this skill to keep ongoing MVP work narrow, stage-aligned, and visibly shippable.

## Governing Docs

Read these before deciding what to build:

1. `AGENTS.md`
2. `README.md`, if present
3. The repo's primary delivery plan:
   `STAGED_DELIVERY.md`, `PLANS.md`, `Docs/PLANS.md`, or equivalent
4. Any docs that `AGENTS.md` says are mandatory for grounding
5. `progress.md` or an equivalent progress log, if present
6. Any feature-specific plan file explicitly referenced by the primary plan

If both `STAGED_DELIVERY.md` and `PLANS.md` exist, treat them differently:
- Use `STAGED_DELIVERY.md` for stage boundaries, acceptance criteria, and feature flags.
- Use `PLANS.md` or a similar file for the slice queue inside the active stage.

If no plan artifact exists beyond `AGENTS.md`, stop and say planning must be completed first.

## Operating Rules

1. Build a short grounding map from the governing docs before coding.
2. Detect the active stage as the first unfinished or first unchecked stage in the plan.
3. Extract the active stage's acceptance criteria, feature flags, and explicit non-goals.
4. Implement exactly one next unfinished vertical slice from that active stage.
5. If the requested work is clearly beyond the active stage, narrow it or defer it unless the user explicitly accepts the tradeoff.
6. Prefer the smallest defensible SwiftUI + SwiftData change that produces visible user value.
7. Reuse the current app structure; avoid speculative abstractions, broad refactors, and unrelated cleanup.
8. If the next slice is too large, split it and implement only the smallest viable sub-slice.
9. Verify the slice before concluding.
10. Update only the smallest relevant tracking artifact; do not rewrite the whole plan.

## Workflow

### 1. Ground The Work

Build a short grounding map with:
- Current product slice
- Binding architecture constraints
- Active stage
- Acceptance criteria relevant to the next slice
- Feature flags relevant to the next slice
- Explicit out-of-scope items for this run

Keep the map brief and concrete.

### 2. Choose The Next Slice

Identify:
- What is already complete
- What is still unfinished in the active stage
- Which unfinished item is the next smallest vertical slice

If the next listed item is still too large, split it into the smallest viable sub-slice that:
- unlocks visible behavior
- fits one pass
- can be verified directly

State the split plainly before coding.

### 3. Restate The Run Before Editing

Before making changes, state:
- The exact slice being implemented
- The user-visible outcome it should unlock
- The files likely to change
- What is intentionally out of scope for this run

Keep this short.

### 4. Implement The Slice

Bias strongly toward:
- Straightforward SwiftUI views
- Direct SwiftData model usage where reasonable
- Existing workflow logic locations such as `DataManager`
- Minimal state complexity
- End-to-end visible behavior

Avoid unless clearly required:
- New service or repository layers
- Protocol-heavy indirection
- Generic base view models
- Broad model redesign
- Cleanup unrelated to the slice

### 5. Use Subagents Sparingly

Use subagents only when they reduce uncertainty for a bounded task.

Good uses:
- read-only codebase exploration
- doc or API verification
- bounded review after implementation

Do not use overlapping writing subagents for the same slice.

### 6. Verify

Verify as far as the environment allows.

When practical:
- run the relevant build
- run or update targeted tests
- sanity-check the user-visible flow for the slice
- sanity-check persistence and feature-flag behavior if data changed

If full verification is not possible, say exactly why and what was still checked.

### 7. Update Tracking

Update only the smallest artifact that the repo already uses for this kind of progress:
- `progress.md` or equivalent progress log
- `PLANS.md` or equivalent slice tracker
- `STAGED_DELIVERY.md` only when completion state or stage evidence genuinely changed

If the repo treats plan files as stage-level release artifacts, leave them unchanged and report progress in the final message instead.

Always record the exact next recommended slice.

## Output

At the end of the run, provide:

1. What changed
2. What now works end-to-end
3. What was verified
4. What was intentionally deferred
5. Any blockers, risks, or assumptions
6. The exact next recommended slice

Keep it concrete and concise.

## MVP Bias

Build the smallest possible working local-first weekly coordination app slice.

Favor:
- Current-week flows
- Direct CRUD hardening
- Visible state-machine progress
- Small feature-flagged additions inside the active stage
- Local persistence correctness

Defer unless the plan explicitly requires them:
- cloud sync
- authentication
- external integrations
- AI suggestions
- broad theming or polish work
- large architectural refactors

## Failure Mode Correction

If scope creep, architecture drift, or plan drift appears:
- stop expanding scope
- restate the current slice
- revert to the smallest path that gets the slice working
- note any drift that should be corrected next
