# Repository Discovery

## Goal

Build the minimum reliable model of the repository needed to design the requested feature, without imposing a predetermined architecture.

Discovery has two layers:

1. **Automatic project detection** (`speckit-radzen detect`) — deterministic, repository-wide facts with evidence and confidence. See `detection-rules.md`.
2. **Feature discovery** (agent) — the feature-specific trace that a detector cannot do.

## Sequence

1. Run `speckit-radzen detect` (phase 00). Read `.speckit/radzen/profile.md`.
2. Read repository instructions the detector listed (`AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, `CONTRIBUTING.md`, `docs/`), and any local constitution amendment.
3. Verify facts marked `inferred` that matter for this feature. Resolve `unknown` facts where possible.
4. Locate the closest analogous feature (see `architecture-detection.md`).
5. Trace the requested capability end-to-end through UI, client/service, DTO/contract, endpoint/application service, validation, authorization, persistence/external dependency, error handling and tests **as they actually exist**.
6. Detect relevant cross-cutting behaviour: authn/authz, ProblemDetails/exception handling, correlation/logging, resilience, caching, feature flags, tenancy, localization, concurrency.
7. Detect test conventions for the layers the feature touches (naming, fixtures, builders, bUnit context setup, test data).
8. Classify repository areas as `READ-ONLY CONTEXT`, `LIKELY CHANGE`, `OUT OF SCOPE` or `UNKNOWN`.
9. Write `specs/NNN-*/discovery.md`.

## Constraints

- Do not modify code during discovery.
- Do not install or upgrade packages.
- Do not infer architecture names without evidence.
- Do not assume an API/backend exists.
- Do not copy secret values from configuration. Key *names* are fine; values never are.

## Output

`discovery.md`: repository summary (link to profile), analogous feature, feature dependency trace, existing conventions, cross-cutting concerns, scope classification, blocking and non-blocking unknowns, out-of-scope findings.
