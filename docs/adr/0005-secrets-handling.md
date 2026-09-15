# ADR-0005: MCP secrets handling

- **Status:** Accepted (2026-09-15)

## Context

Radzen Blazor MCP authenticates with an `X-Radzen-Key` HTTP header containing a license key.

## Decision

- The kit never writes a literal key. Templates reference an environment variable (`RADZEN_MCP_KEY`) or the client's secure input prompt.
- `Test-McpConfiguration` and the anti-pattern rule `AP-SEC-05` fail when a literal key appears in any MCP configuration file inside the repository.
- Agents must refuse to write a pasted key to a tracked file and propose the environment-variable route instead.
- Documentation explains per client where user-level configuration lives (outside the repository) for users who prefer that.

## Consequences

Some clients may not support environment-variable expansion in every field. For those, the template targets the user-level configuration file, never the repository.
