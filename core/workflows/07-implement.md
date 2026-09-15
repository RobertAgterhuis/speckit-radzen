# Phase 07 — Implement

**Purpose:** implement one slice at a time, verifying each before the next.

## Entry — G4 passed (and, for slice n > 1, G5 + G6 passed for slice n-1)

## Reads (per task)

The task in `tasks.md`, the related section of `plan.md`, the `MCP-###` entries it references, `antipatterns/index.md`, and the exact files it touches.

## Per-task loop

1. Re-read the task and the constitution principles it touches.
2. Open the exact files, and the analogous feature identified in discovery.
3. **MCP loop** (`mcp/mcp-workflow.md`): for any Radzen API the task needs that has no evidence yet, query the Radzen MCP *before* writing code and record it with `speckit-radzen evidence add`. Reuse existing evidence; do not re-query what is already recorded for the same component and version.
4. Make the smallest coherent change. Follow the analogous feature's conventions.
5. Tick the task in `tasks.md` (`- [x]`).

## Per-slice gates

1. `speckit-radzen gate G5 -Feature NNN -Slice S-##` — builds the affected projects and runs the relevant tests. It compares warnings against the baseline.
2. `speckit-radzen gate G6 -Feature NNN` — scans changed files for anti-patterns.
3. Fix failures. Classify each remaining build/test failure as `introduced`, `pre-existing (proven)` or `unknown`. `unknown` is a stop condition.
4. Record the slice as done: `speckit-radzen phase implement -Feature NNN -CompleteSlice S-##`.

## Never

- invent Radzen APIs or copy APIs from another component library;
- upgrade or downgrade `Radzen.Blazor` (or any package) to make code compile;
- disable, skip or delete tests, or suppress warnings/analyzers, to pass a gate;
- weaken authorization or swallow exceptions;
- add dependencies not approved in the plan;
- refactor code unrelated to the task;
- write secrets to any file.

## Exit

All slices have passed G5 and G6.
