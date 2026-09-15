# Workflow: Implement
For each approved task:
1. Re-read task and relevant constitution.
2. Inspect exact files.
3. Query Radzen MCP before coding when Radzen API knowledge is required.
4. Make the smallest coherent change.
5. Preserve existing conventions.
6. Build the smallest useful scope.
7. Run relevant tests.
8. Review warnings/errors attributable to the slice.
9. Review security and UI states.
10. Continue only after the slice gate passes.

Never invent Radzen APIs, disable tests to pass, weaken authorization, swallow unknown exceptions, silently add dependencies, or refactor unrelated code.

Classify failures as introduced, proven pre-existing, or unknown. Unknown failures are a stop condition.
