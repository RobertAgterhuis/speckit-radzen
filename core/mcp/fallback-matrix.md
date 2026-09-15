# MCP Fallback Matrix

| Situation | Detect | Allowed action | Evidence to record | Stop? |
|---|---|---|---|---|
| MCP not configured | `mcp-check` → `not-configured`; no Radzen tool in tool list | Use rank 1–2 sources (compiler, project-local usage). Use official docs (rank 4) only with the user's approval. Suggest configuring MCP (`docs/mcp-setup.md`). | `-Source project` / `-Source docs -FallbackApproved -FallbackReason "MCP not configured, approved by <name>"` | Stop if the API is not proven by rank 1–2 and the user does not approve rank 4 |
| MCP configured but unreachable / 401 | tool call fails; `mcp-check -Probe` → `unreachable` / `unauthorized` | Retry once. Then as "not configured". Record `-McpAvailability unavailable`. | as above | as above |
| Quota exhausted (trial) | tool returns a quota/limit error | Record `-McpAvailability quota-exhausted`. Reuse existing evidence. Otherwise as "not configured". | as above | as above |
| MCP answer conflicts with installed version (compile error, member missing) | G5 build error on a Radzen member | Record the conflict (`-Status conflict`). Search project usage and the package's XML docs for the correct member for the installed version. Re-query MCP mentioning the installed version. | New entry with `-Source compiler`, `-Supersedes MCP-###` | **Yes**, if no version-correct API is found. Never upgrade/downgrade the package as a fix |
| MCP answer conflicts with project-local usage | existing code uses a different pattern | Project usage wins for style; MCP wins for correctness only if project usage is demonstrably wrong (then it is an out-of-scope finding, not a silent change). | Entry with both sources | Stop if the choice changes behaviour and precedence is unclear (P-13.3) |
| MCP answer is ambiguous or generic | answer does not name the member | Ask a narrower query (component + member + version). | Only record the useful answer | Stop after two unsuccessful narrowed queries → report knowledge gap |
| API only exists in a newer Radzen version | MCP says "since vX"; installed < vX | Do not use it. Find an alternative for the installed version, or propose an upgrade as a **separate, approved** scope. | Entry with `-Status conflict` | Yes, until the user decides |
| Studio MCP unavailable | Studio not open / not configured | Work without Studio. Studio is never required. | — | No |
