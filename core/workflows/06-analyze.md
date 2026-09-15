# Phase 06 — Analyze

**Purpose:** check that spec, plan, tasks, test scenarios and MCP evidence agree with each other before any code is written.

## Entry

`spec.md`, `plan.md`, `tasks.md`, `test-scenarios.md` and `mcp-evidence.json` exist.

## Steps

1. Run `speckit-radzen analyze -Feature NNN`. It writes `analysis.md` with:
   - FR → AC → TS → T traceability matrix;
   - FRs without tasks, tasks without FRs (orphans), ACs without test scenarios;
   - `MCP-###` references in plan/tasks that do not exist in the evidence log, and evidence entries whose source rank is too weak;
   - slices without tasks, tasks without slices.
2. Read the report and fix the artifacts. Do not change requirements silently: a requirement change goes back through phase 02/03 and is recorded in `clarifications.md`.
3. Semantic checks the tool cannot do — review them yourself and note the result in `analysis.md` under *Manual findings*:
   - Does the plan contradict the spec (e.g. client-side paging for an unbounded list)?
   - Do tasks implement something no FR asks for (scope creep)?
   - Is every authorization rule in the matrix enforced by some task at the trusted boundary?
4. Run `speckit-radzen gate G4 -Feature NNN`.

## Exit — G4

Zero traceability errors; every Radzen API has evidence of rank ≤ 3 or an approved fallback.
