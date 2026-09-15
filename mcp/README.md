# Radzen MCP Integration

Spec Kit Radzen expects the agent to have access to the current Radzen Blazor MCP when Radzen API knowledge is required.

## Principles

- Configure MCP in the AI client/user environment according to current Radzen and client documentation.
- Do not commit Radzen license keys, tokens, or other credentials.
- Keep MCP configuration separate from the Spec Kit core.
- The repository's installed `Radzen.Blazor` version and successful compilation remain the final compatibility boundary.
- Radzen Blazor Studio MCP is optional and does not override repository architecture or quality gates.

This distribution intentionally does not embed credentials or assume a particular MCP-client configuration schema.
