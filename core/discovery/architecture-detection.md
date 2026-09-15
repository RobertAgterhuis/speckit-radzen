# Architecture Detection

Describe what exists; do not prescribe what should exist.

## Tracing

Trace the requested feature through actual project references, namespaces, DI registrations, endpoint routing, services, persistence, HTTP clients, Razor dependencies, shared projects and tests. The detector's `projects` and `projectGraph` sections in `profile.json` are the starting point.

## Finding the analogous feature

Search, in this order:

1. A page/component in the same project that shows the same kind of data (grid, form, dialog, dashboard) — search for the Radzen component (`<RadzenDataGrid`, `<RadzenTemplateForm`, `DialogService.OpenAsync`).
2. A feature that talks to the same backend area (same client/service/endpoint group).
3. The most recently changed comparable feature (`git log --since` on the pages folder), which usually reflects current conventions best.

Record the files. They are the style reference for naming, folder placement, service injection, error handling, notifications and tests.

## Precedence when patterns conflict

1. The closest analogous feature.
2. The dominant pattern in the same project.
3. The repository-wide convention.
4. A new pattern — only when necessary and approved in the plan.

If two active patterns compete and none of these rules decides, that is stop condition P-13.3: ask.

## Brownfield inconsistencies

Do not repair architectural inconsistency as part of unrelated Radzen work. Record it under *Out-of-scope findings* unless it blocks the feature.

## Signals worth checking manually (the detector only infers these)

| Question | Evidence to look for |
|---|---|
| Does UI call the backend directly or via a client abstraction? | `HttpClient` injection in `.razor`, typed clients, Refit interfaces, `I*Service` in a shared project |
| Where is validation enforced? | FluentValidation validators, `IValidatableObject`, endpoint filters, MediatR behaviours, DataAnnotations on DTOs |
| Where is authorization enforced? | `[Authorize]`, `RequireAuthorization`, policy registrations, resource-based handlers, checks inside application services |
| Error contract | `AddProblemDetails`, `IExceptionHandler`, `Results.Problem`, custom `Result<T>` types |
| State | cascading parameters, scoped state services, Fluxor, `PersistentComponentState` |
| Concurrency | row version / ETag columns, `DbUpdateConcurrencyException` handling |
