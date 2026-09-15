---
name: speckit-radzen
description: Repository-aware feature engineering for Radzen Blazor. Use for discovering, specifying, planning, implementing, or reviewing Radzen-based application features while preserving the repository architecture and validating Radzen APIs through MCP.
---

# Spec Kit Radzen

Use the Spec Kit Radzen core as the governing workflow for Radzen-related feature engineering.

## Mandatory behavior

1. Read the constitution before implementation.
2. Inspect the relevant repository architecture before proposing UI changes.
3. Preserve existing backend, middleware, security, validation, persistence, testing, and UI conventions.
4. Perform capability/gap analysis before planning.
5. Use Radzen MCP when current Radzen component/API knowledge is required.
6. Never invent Radzen properties, events, methods, or services.
7. Treat installed package version plus successful compilation as the compatibility boundary.
8. Never treat hidden/disabled UI as authorization enforcement.
9. Implement in small coherent vertical slices.
10. Apply build/test/security/responsive/accessibility quality gates.

## Core references

The canonical policy is under `.speckit/radzen/core/`.

Read only the references required for the current phase, plus the constitution.

### Discover
- `.speckit/radzen/core/constitution/constitution.md`
- `.speckit/radzen/core/discovery/repository-discovery.md`
- `.speckit/radzen/core/discovery/architecture-detection.md`
- `.speckit/radzen/core/templates/project-profile.md`

### Specify / Clarify
- `.speckit/radzen/core/workflows/specify.md`
- `.speckit/radzen/core/workflows/clarify.md`
- `.speckit/radzen/core/templates/feature-spec.md`
- `.speckit/radzen/core/templates/gap-analysis.md`

### Plan / Tasks
- `.speckit/radzen/core/workflows/plan.md`
- `.speckit/radzen/core/workflows/tasks.md`
- `.speckit/radzen/core/templates/implementation-plan.md`
- `.speckit/radzen/core/templates/tasks.md`

### Implement
- `.speckit/radzen/core/workflows/implement.md`
- applicable files under `.speckit/radzen/core/standards/`
- applicable files under `.speckit/radzen/core/patterns/`

### Review
- `.speckit/radzen/core/workflows/review.md`
- `.speckit/radzen/core/checklists/definition-of-done.md`
- applicable security/responsive checklists

## Invocation intent

When explicitly invoked with a phase, execute that phase:
- `discover`
- `specify`
- `clarify`
- `plan`
- `tasks`
- `implement`
- `review`

If no phase is given, infer the narrowest appropriate phase from the user's request. Do not jump directly to implementation when discovery/specification evidence is insufficient.
