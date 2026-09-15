# Repository Discovery

## Goal
Build the minimum reliable model of the repository needed to design the requested feature without imposing a predetermined architecture.

## Sequence
1. Inspect `.sln`/`.slnx`, project files, `global.json`, central package management, repository instructions, and relevant CI/build configuration.
2. Detect Blazor/Radzen frontend, render model, package versions, layouts/pages/components, shared UI, wrappers, theme/CSS, localization, clients/services, and state patterns.
3. Trace the requested capability end-to-end through UI, client/service, DTO/contract, endpoint/application service, validation, authorization, persistence/external dependency, error handling, and tests as they actually exist.
4. Detect relevant cross-cutting behavior: authn/authz, ProblemDetails/exception handling, correlation/logging, resilience, caching, feature flags, tenancy, localization, concurrency.
5. Detect test conventions.
6. Populate the project profile.
7. Classify repository areas as `READ-ONLY CONTEXT`, `LIKELY CHANGE`, `OUT OF SCOPE`, or `UNKNOWN`.

## Constraints
- Do not modify code during discovery.
- Do not install or upgrade packages.
- Do not infer architecture names without evidence.
- Do not assume an API/backend exists.
- Do not expose secrets from configuration.

## Output
Repository summary, project profile, feature dependency path, existing conventions, uncertainties, and initial scope boundary.
