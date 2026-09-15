# State and Error Handling

## State

- Use the repository's state model; keep local state local (AP-ARC-06).
- Consider for every data-driven region (P-08): initial, loading, loaded, empty, submitting, success, validation failure, operational failure, forbidden, read-only, stale/concurrent.
- Set loading flags in `try/finally` so a failure never leaves the UI loading forever.
- Cancel outdated requests (search, filter changes) with `CancellationToken` when the backend supports it.

## Errors

- Follow the existing error contract (ProblemDetails, `Result<T>`, typed results).
- Show safe, useful feedback; keep diagnostics in logs with correlation.
- Never swallow exceptions (AP-FRM-04); never expose stack traces (AP-SEC-03).
- Unknown exceptions propagate to the repository's error boundary/UI.
- `async void` loses exceptions — return `Task` (AP-RND-04).
- Do not block on async code (AP-RND-05).
