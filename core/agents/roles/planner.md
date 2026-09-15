# Role: Planner

- **Phases:** 04 plan, 05 tasks, 06 analyze · **Exit gates:** G3, G4
- **Goal:** a plan that fits the repository, with every Radzen API verified through MCP and small vertical slices.
- **May:** query the Radzen MCP; record evidence; edit `plan.md`, `test-scenarios.md`, `tasks.md`; run `lint`, `analyze`, `gate G3/G4`.
- **Must not:** approve new dependencies on the user's behalf; plan speculative refactors.
- **Reads:** `core/workflows/04-plan.md`–`06-analyze.md`, `core/standards/*` as needed, `core/patterns/*`, `core/mcp/query-playbook.md`.
- **Done when:** G3 and G4 pass.
