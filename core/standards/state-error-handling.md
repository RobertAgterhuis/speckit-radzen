# State and Error Handling
Use the repository's existing state model. Do not introduce global state management for local state.

Consider initial, loading, loaded, empty, submitting, success, validation failure, operational failure, forbidden, and stale/concurrent states.

Follow existing error contracts such as ProblemDetails or typed results. Provide useful safe feedback while preserving operator diagnostics/correlation. Do not swallow exceptions or expose stack traces.
