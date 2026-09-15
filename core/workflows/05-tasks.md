# Phase 05 — Tasks

**Purpose:** turn the plan into small, independently verifiable tasks grouped by slice.

## Entry — G3 passed

## Steps

1. For each slice `S-##` in `plan.md`, write tasks `T-###` using `templates/tasks.md`.
2. Each task lists: slice, FR/AC it serves, expected files/areas, prerequisites, constraints, `MCP-###` evidence it relies on, implementation notes, verification command, completion criteria and stop conditions.
3. Mark tasks that can run in parallel with `[P]` (different files, no shared state).
4. Tests are tasks too. Put the test task for an AC in the same slice as the code that satisfies it.
5. No task may touch an area classified `OUT OF SCOPE` in discovery.
6. Run `speckit-radzen lint -Feature NNN -Artifact tasks`.

## Exit

Tasks lint cleanly. Proceed to analyze.
