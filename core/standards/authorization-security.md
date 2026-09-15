# Authorization and Security

The browser is not a trusted boundary (P-07). UI authorization (`AuthorizeView`, hidden/disabled buttons) improves UX only.

## For every sensitive operation

Record in the spec authorization matrix: actor/policy → trusted enforcement point (endpoint, application service, handler) → data exposed → forbidden behaviour. A missing enforcement point is a gap to plan, not an assumption (AP-SEC-01/02).

## Rules

- Enforce policies server-side: `[Authorize(Policy=…)]`, `RequireAuthorization(…)`, resource-based handlers, or checks in application services — whatever the repository uses.
- New screens often call endpoints that were never exposed to that audience; check every endpoint in the dependency trace.
- Minimize data: project only needed fields; do not log sensitive values (AP-SEC-08/10).
- Never display raw exceptions, tokens, connection strings or secrets (AP-SEC-03/04).
- Keep antiforgery and existing middleware (AP-SEC-09); `[AllowAnonymous]` needs an approved reason (AP-SEC-06).
- Do not render unsanitized HTML (`MarkupString`) (AP-SEC-07).
- Secrets live in user secrets, environment variables or a secret store — including the Radzen MCP key (AP-SEC-05, ADR-0005).
