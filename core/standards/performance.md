# Performance

Evaluate: request count, payload size, cardinality, rendering cost, repeated renders, expensive templates, cancellation, debounce and server query support. Do not optimize speculatively; do not ignore credible risks (P-10).

- Server-side paging/filtering for unbounded data; materialize last (AP-DAT-01).
- No service calls per row in templates — project the data (AP-PERF-01).
- Debounce search-as-you-type and cancel stale requests (AP-PERF-02).
- Reuse HTTP clients via DI (AP-PERF-03).
- Avoid `StateHasChanged` in loops and `Reload` in loops (AP-RND-06, AP-RDZ-08).
- Use `@key` for dynamic component lists (AP-RND-07).
- Aggregate dashboards on the server (AP-DAT-03).
- Full client materialization of unbounded data requires an explicit, approved justification.
