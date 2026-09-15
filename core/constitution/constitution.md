# Spec Kit Radzen Constitution

- **Version:** 2.0.0 (ratified 2026-09-15)
- **Supersedes:** 1.0.0 (principles I–XIV are preserved as P-01 … P-14)

`MUST`, `MUST NOT`, `SHOULD`, `SHOULD NOT` and `MAY` are normative (RFC 2119).

Each principle lists the quality gates that enforce it (see `gates/quality-gates.md`) and the anti-pattern categories that describe how it is typically violated (see `antipatterns/index.md`).

---

## P-01 Repository Awareness

Before designing or modifying a Radzen feature, the agent MUST inspect the repository areas relevant to the capability: solution/project structure, UI, shared components, domain/application code, DTOs/contracts, API/endpoints, authentication, authorization, middleware, validation, DI, persistence, logging/observability, localization, state management and tests when present.

The agent MUST run automatic project detection (`speckit-radzen detect`) before feature discovery and MUST treat a stale profile as missing.

Discovery MAY inspect broadly enough to understand dependencies. Modification MUST remain inside the approved feature scope.

- Gates: G0, G1 · Anti-patterns: AP-AGT

## P-02 Architecture Preservation

Existing project conventions take precedence over agent preference. The agent MUST NOT introduce a new architecture, framework, wrapper, service layer, state framework, validation library, mapping library, package or test framework unless it is required, absent from the repository, and explicitly approved in the plan.

The agent SHOULD use the closest analogous implementation already present in the repository.

- Gates: G3, G7 · Anti-patterns: AP-ARC

## P-03 Radzen MCP First

When implementation depends on Radzen component behaviour, properties, events, methods, services, enums, binding or supported patterns, the agent MUST consult the configured Radzen Blazor MCP when available, following `mcp/mcp-workflow.md`.

The agent MUST NOT invent Radzen APIs.

The installed package version and successful compilation are the final compatibility boundary. If MCP guidance conflicts with the installed version or the compiler, the agent MUST stop and resolve the discrepancy (see `mcp/fallback-matrix.md`).

If MCP is unavailable, the agent MAY proceed only when the API is proven by project-local usage or another authoritative source; otherwise it MUST report the knowledge gap.

- Gates: G0, G3, G4, G5 · Anti-patterns: AP-RDZ, AP-AGT

## P-04 Version Awareness

The agent MUST use the detected SDK, target framework(s), Blazor hosting model, render mode(s), `Radzen.Blazor` version and test packages. It MUST NOT hardcode version assumptions. Package upgrades are separate scope unless explicitly required and approved.

- Gates: G0, G7 · Anti-patterns: AP-AGT, AP-ARC

## P-05 Requirement-Driven Component Selection

Components are chosen by required interaction, local conventions, data volume, responsiveness, accessibility, performance and maintainability. Familiarity alone is not a justification.

Preference order: existing project component/pattern → suitable supported Radzen component → composition of supported primitives → custom implementation when justified.

- Gates: G3, G7 · Anti-patterns: AP-RDZ, AP-ARC

## P-06 Separation of Concerns

UI code focuses on presentation, interaction, presentation state, input collection, UX validation and orchestration through approved interfaces. It MUST NOT duplicate backend business rules or persistence logic, and MUST NOT bind persistence entities directly when the repository uses contracts or view models.

- Gates: G6, G7 · Anti-patterns: AP-FRM, AP-ARC

## P-07 Security Boundary

Hidden, disabled or absent controls are not authorization enforcement. Sensitive operations MUST be authorized at the trusted server/application boundary. The feature MUST request, cache, log, render and transport only the data it needs. Secrets (including MCP keys) MUST NOT be written to tracked files.

- Gates: G2, G6, G7 · Anti-patterns: AP-SEC

## P-08 Explicit UI States

For data-driven features the specification and implementation MUST consciously address: initial, loading, success, empty, validation failure, operational failure, unauthorized/forbidden, disabled/read-only and concurrency/stale state where relevant.

- Gates: G2, G7 · Anti-patterns: AP-FRM, AP-DAT

## P-09 Responsive and Accessible Baseline

Changed interactive UI MUST consider desktop/tablet/mobile layout, overflow, keyboard operation, focus, labels/accessible names, error communication, touch interaction, dialog usability and grid behaviour at constrained widths.

- Gates: G2, G6, G7 · Anti-patterns: AP-A11Y, AP-RSP

## P-10 Data-Volume Awareness

The agent MUST NOT assume datasets are small. For potentially unbounded collections it MUST evaluate server paging/filtering/sorting, virtualization, projection, incremental loading, cancellation and request frequency, and record the data-volume assumption in the spec.

- Gates: G2, G3, G6 · Anti-patterns: AP-DAT, AP-PERF

## P-11 Small Vertical Slices

Work is delivered as the smallest coherent change that can be built and verified on its own. Unrelated refactoring MUST NOT be mixed into feature work.

- Gates: G3, G5 · Anti-patterns: AP-ARC

## P-12 Verification

Every slice passes G5 (build/test) and G6 (anti-pattern scan). The feature passes G7 (review) and G8 (done). A gate is only reported as passed when a gate result file exists.

- Gates: G5–G8 · Anti-patterns: AP-TST, AP-AGT

## P-13 Stop Conditions

The agent MUST stop and surface the issue when:

1. authorization is materially ambiguous;
2. a Radzen API cannot be verified;
3. repository patterns conflict without clear precedence;
4. a required backend/contract change is outside approved scope;
5. relevant tests fail for unresolved reasons, or a failure cannot be classified;
6. a material dependency/architecture change was not approved;
7. destructive or data-loss behaviour is not explicitly authorized;
8. the target solution is ambiguous (multiple solutions, none selected);
9. a gate returns "cannot evaluate" (exit code 3);
10. a user asks to commit a secret.

- Gates: all

## P-14 Evidence Over Assumption

Repository evidence takes precedence over generic convention. Unknown facts remain `unknown`; they are never invented. Every fact in the project profile carries evidence (file and line) and a confidence level.

- Gates: G1, G4 · Anti-patterns: AP-AGT

## P-15 Recorded MCP Evidence

Every Radzen component, member or service used by the plan or implementation MUST have an `MCP-###` entry in `mcp-evidence.json`, with its source rank. Rank 5 (model knowledge) alone is never sufficient.

- Gates: G4 · Anti-patterns: AP-AGT

## P-16 Render-Mode Correctness

Interactive Radzen components MUST run in an interactive render mode that matches the repository's hosting model. The Radzen service registration (`AddRadzenComponents()` or equivalent), theme, script and component host (`<RadzenComponents />`) MUST be present and consistent with that render mode. Prerendering effects (double loading, `LoadData` not raised during prerender) MUST be handled deliberately.

- Gates: G0, G6, G7 · Anti-patterns: AP-RND, AP-RDZ

---

## Governance

- **Precedence:** this constitution → repository-local amendments (`.speckit/radzen/local/constitution.local.md`) → phase workflows → standards/patterns → agent preference. A local amendment MAY tighten a principle. It MAY relax one only with a written rationale, and it MUST NOT relax P-07.
- **Amendments** to this file require an ADR, a version bump (MAJOR for removed/relaxed principles, MINOR for new principles, PATCH for wording) and a CHANGELOG entry.
- **Compliance** is checked in the plan's *Constitution Check* table (G3) and in the review (G7). Violations are either fixed or recorded as justified deviations with approval.
