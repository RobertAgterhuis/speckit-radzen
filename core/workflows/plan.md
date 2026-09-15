# Workflow: Plan
1. Reconfirm relevant architecture and feature gaps.
2. Determine which layers actually require changes.
3. Identify Radzen knowledge that must be verified through MCP.
4. Define security/authorization enforcement.
5. Define data flow and UI states.
6. Define tests using the existing stack.
7. Break work into small vertical slices.
8. Define quality gates and stop conditions.

Classify UI, shared UI, contracts, application/services, API/endpoints, middleware, authorization, persistence, tests, and configuration as `no change`, `modify`, `add`, or `unknown`.

Do not include speculative refactors.
