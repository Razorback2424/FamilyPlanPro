# CHANGELOG

## Unreleased
- Stage 1: Route grocery-list screen cadence updates through DataManager so notification eligibility is decided in one place.
- Stage 1: Make grocery cadence timing deterministic under test and cover the remaining-days-only Sun/Thu scheduling rules.
- Stage 1: Cancel stale Sun/Thu grocery cadence notifications whenever a grocery list becomes ineligible for the current week.
- Stage 1: Add grocery-list accessibility hooks and a UI smoke path for grouped sections plus manual item edits.
- Stage 1: Hide ownership-rule and Simple Friday UI affordances when meal ownership rules are turned off.
- Stage 1: Add one-tap Simple Friday meal templates in the Suggestions flow.
- Stage 1: Add day-by-day weekly meal ownership editing in the Suggestions flow, with rule changes reapplying to unsaved meals.
- Stage 1: Allow weekly budget target and observed spend updates directly from the finalized weekly meal flow.
- Stage 0: Auto-bootstrap a default Family and Current Week with 7 dinner slots on first launch.
- Stage 0: Add Reopen-to-Suggestions from Review and Finalized (with confirmation in Finalized).
- Stage 0: Deterministic cleanup for replacing pending/final suggestions and deleting slots.
- Stage 0: Finalized summary now reflects selected meals and is read-only.
- Tests: Added unit coverage for bootstrap, reopen transitions, and orphan cleanup; updated UI bootstrap expectations.
