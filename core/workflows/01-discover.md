# Phase 01 — Discover

**Purpose:** build the minimum reliable model of the repository that the feature needs. Describe what exists; do not prescribe what should exist.

## Entry — G0 passed

## Reads

`discovery/repository-discovery.md`, `discovery/architecture-detection.md`, `.speckit/radzen/profile.md`, `templates/discovery.md`.

## Steps

1. Start from `profile.md`. Do not repeat what the detector already proved; verify anything marked `inferred`, and try to resolve anything marked `unknown` that matters for this feature.
2. Find the **closest analogous feature** in the repository (a similar page, grid, form or dialog). Record its files; it is the primary style reference.
3. Trace the requested capability end-to-end as it actually exists:
   `UI → client/service → contract/DTO → endpoint/application service → validation → authorization → persistence/external dependency → error handling → tests`.
4. Record cross-cutting behaviour that touches the feature: authn/authz policies, ProblemDetails/exception handling, correlation/logging, resilience, caching, feature flags, tenancy, localization, concurrency.
5. Record Radzen specifics that affect the feature: render mode of the target page, existing wrappers around Radzen components, dialog/notification conventions, theme.
6. Classify repository areas as `READ-ONLY CONTEXT`, `LIKELY CHANGE`, `OUT OF SCOPE` or `UNKNOWN`.
7. List blocking unknowns separately from non-blocking ones.
8. Write `specs/NNN-*/discovery.md` from `templates/discovery.md`.
9. Run `speckit-radzen gate G1 -Feature NNN`.

## Constraints

- Do not modify code. Do not install or upgrade packages.
- Do not name an architecture ("Clean Architecture", "CQRS") without evidence.
- Do not assume a backend endpoint exists.
- Never copy secret values from configuration into any artifact.

## Exit — G1

`discovery.md` has a dependency trace, an analogous-feature reference, a scope classification and no unresolved *blocking* unknowns.

## Anti-patterns to watch

AP-AGT-01 (skipping discovery), AP-AGT-05 (invented facts), AP-ARC-04 (repairing unrelated brownfield inconsistencies).
