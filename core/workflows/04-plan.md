# Phase 04 — Plan

**Purpose:** decide *how* the feature will be built within the repository's architecture, and which Radzen knowledge must be verified.

## Entry — G2 passed

## Reads

`templates/plan.md`, the relevant `standards/` and `patterns/` files, `mcp/mcp-workflow.md`, `mcp/query-playbook.md`, `templates/test-scenarios.md`.

## Steps

1. **Constitution check.** Fill the table for P-01 … P-16: `complies`, `n/a` or `deviation` (with justification and approver).
2. **Layer impact.** Classify UI, shared UI, contracts, application/services, API/endpoints, middleware, authorization, persistence, tests and configuration as `no change`, `modify`, `add` or `unknown`. `unknown` is not allowed at G3.
3. **Component strategy.** For each UI element name the component (existing wrapper first, then Radzen component, then composition, then custom) with the reason (P-05).
4. **MCP verification (P-03, P-15).** List every Radzen component, member and service the plan relies on. For each, run the MCP loop in `mcp/mcp-workflow.md` now and record the result with `speckit-radzen evidence add …`. Reference the `MCP-###` IDs in the plan.
5. **Security model.** Actor → operation → enforcement point → data exposed → forbidden behaviour.
6. **Data flow.** Request/response shapes, where paging/filtering/sorting happen, cancellation, caching.
7. **UI states & responsive/a11y strategy** per screen.
8. **Render mode.** State the render mode of each changed page/component and how prerendering is handled (P-16).
9. **Testing strategy.** Using the detected test stack only. Write `test-scenarios.md` mapping every AC to at least one `TS-###` and test level.
10. **Vertical slices (`S-##`).** Each slice: objective, FRs covered, areas/files, prerequisites, verification command, stop conditions. The first slice is the thinnest end-to-end path.
11. **Dependencies.** New packages or projects are listed explicitly under *Approved dependency changes*; anything not listed will fail G7.
12. Risks and explicit non-goals.
13. Run `speckit-radzen lint -Feature NNN -Artifact plan`, then `speckit-radzen gate G3 -Feature NNN`.

## Exit — G3

Constitution check has no unjustified deviations; no `unknown` layer impact; every planned Radzen API has an `MCP-###` reference; every slice has verification and stop conditions.

## Anti-patterns to watch

AP-ARC-01 (unapproved dependency), AP-ARC-02 (wrapper without value), AP-ARC-03 (speculative refactor), AP-RDZ-02 (materialized grid data), AP-RND-01 (static page with interactive component).
