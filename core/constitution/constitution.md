# Radzen Spec Kit Constitution

`MUST`, `MUST NOT`, `SHOULD`, `SHOULD NOT`, and `MAY` are normative.

## I. Repository Awareness
Before designing or modifying a Radzen feature, inspect repository areas relevant to the capability: solution/project structure, UI, shared components, domain/application code, DTOs/contracts, API/endpoints, authentication, authorization, middleware, validation, DI, persistence, logging/observability, localization, state management, and tests when present.

Discovery may inspect broadly enough to understand dependencies. Modification MUST remain inside approved feature scope.

## II. Architecture Preservation
Existing project conventions take precedence over agent preference. Do not introduce a new architecture, framework, wrapper, service layer, state framework, validation library, mapping library, or test framework unless required, absent from the repository, and explicitly approved in the plan.

Prefer the closest analogous implementation already present in the repository.

## III. Radzen MCP First
When implementation depends on Radzen component behavior, properties, events, methods, services, enums, binding, or supported patterns, consult the configured Radzen Blazor MCP when available.

Never invent Radzen APIs.

The installed package version and successful compilation are the final compatibility boundary. If MCP guidance conflicts with the installed version or compiler, stop and resolve the discrepancy.

If MCP is unavailable, proceed only when the API is already proven by project-local code or another authoritative source; otherwise report the knowledge gap.

## IV. Version Awareness
Detect SDK, target framework(s), Blazor model/render mode, Radzen.Blazor version, and relevant test packages. Do not hardcode version assumptions. Upgrades are separate scope unless explicitly required.

## V. Requirement-Driven Component Selection
Choose components using required interaction, local conventions, data volume, responsiveness, accessibility, performance, and maintainability. Familiarity alone is not justification.

Prefer, in order: existing project component/pattern; suitable supported Radzen component; composition of supported primitives; custom implementation when justified.

## VI. Separation of Concerns
UI code focuses on presentation, interaction, presentation state, input collection, UX validation, and orchestration through approved interfaces. Do not duplicate backend business rules or persistence logic in UI components.

## VII. Security Boundary
Hidden, disabled, or absent controls are not authorization enforcement. Sensitive operations must be authorized at the trusted server/application boundary. Request, cache, log, render, and transport only data needed by the feature.

## VIII. Explicit UI States
For data-driven features consciously consider initial, loading, success, empty, validation failure, operational failure, unauthorized/forbidden, disabled/read-only, and concurrency/stale state where relevant.

## IX. Responsive and Accessible Baseline
Changed interactive UI must consider desktop/tablet/mobile layout, overflow, keyboard operation, focus, labels/accessible naming, error communication, touch interaction, dialog usability, and grid behavior at constrained widths.

## X. Data-Volume Awareness
Do not assume datasets are small. For potentially unbounded collections evaluate server paging/filtering/sorting, virtualization, projection, incremental loading, cancellation, and request frequency.

## XI. Small Vertical Slices
Implement the smallest coherent change that can be independently built and verified. Do not mix unrelated refactoring into feature work.

## XII. Verification
Applicable completion gates include build, tests, repository analyzers, Radzen API validation, authorization/security review, responsive/accessibility review, UI-state review, and absence of unexplained architecture drift.

## XIII. Stop Conditions
Stop and surface the issue when authorization is materially ambiguous; a Radzen API cannot be verified; repository patterns conflict without clear precedence; a required backend/contract change is outside approved scope; relevant tests fail for unresolved reasons; a material dependency/architecture change was not approved; or destructive/data-loss behavior is not explicitly authorized.

## XIV. Evidence Over Assumption
Repository evidence takes precedence over generic convention. Unknown facts remain unknown; do not invent them.
