# Radzen MCP Setup

Spec Kit Radzen expects the **Radzen Blazor MCP** for current component knowledge. This guide covers licences, keys, and each client.

## Facts (verified 2026-09-15)

| | |
|---|---|
| Endpoint | `https://app.radzen.com/mcp` (Streamable HTTP) |
| Authentication | header `X-Radzen-Key: <licence key>` |
| Tool | `search` — natural-language questions about components, APIs, samples, templates |
| Licence | Free trial (limited requests over a limited period — 50 requests / 15 days at the time of writing); unlimited with Radzen Blazor Pro or Team |
| Optional | Radzen Blazor Studio MCP: a local server provided by Radzen Blazor Studio for design-time actions (see `core/mcp/studio-guardrails.md`) |

Re-check the Radzen documentation when a client shows different behaviour, and update `core/mcp/tool-map.md`.

## 1. Store the key outside the repository

```powershell
[Environment]::SetEnvironmentVariable('RADZEN_MCP_KEY', '<key>', 'User')   # Windows (restart IDE/terminal)
```

```bash
echo "export RADZEN_MCP_KEY='<key>'" >> ~/.zshrc   # or ~/.bashrc
```

Never commit a key. `mcp-check`, gate G0 and anti-pattern AP-SEC-05 fail when a literal key is found in a tracked file. If a key was ever committed, rotate it.

## 2. Configure your client

The installer can write the repository-level entries (`-McpClient …`). Manual equivalents:

### Claude Code

`.mcp.json` (project scope, committed):

```json
{ "mcpServers": { "radzen-blazor": { "type": "http", "url": "https://app.radzen.com/mcp", "headers": { "X-Radzen-Key": "${RADZEN_MCP_KEY}" } } } }
```

Claude Code asks you to approve project servers. If headers are not expanded in your version, add the server at user scope instead:

```bash
claude mcp add --scope user --transport http radzen-blazor https://app.radzen.com/mcp --header "X-Radzen-Key: $RADZEN_MCP_KEY"
```

### VS Code (GitHub Copilot)

`.vscode/mcp.json` — VS Code prompts for the key once and stores it securely:

```json
{
  "inputs": [ { "type": "promptString", "id": "radzen-key", "description": "Radzen Blazor MCP license key", "password": true } ],
  "servers": { "radzen-blazor": { "type": "http", "url": "https://app.radzen.com/mcp", "headers": { "X-Radzen-Key": "${input:radzen-key}" } } }
}
```

Use Copilot in **agent** mode so MCP tools are available.

### Visual Studio 2022 (17.14+)

Use a file that is not committed: `%USERPROFILE%\.mcp.json` (all solutions) or `<solution>\.vs\mcp.json`. Same content as VS Code. If your version does not prompt for inputs, put the key directly in that user-level file — never in the solution's tracked `.mcp.json`.

### Cursor

`.cursor/mcp.json`:

```json
{ "mcpServers": { "radzen-blazor": { "url": "https://app.radzen.com/mcp", "headers": { "X-Radzen-Key": "${env:RADZEN_MCP_KEY}" } } } }
```

If interpolation in headers does not work in your Cursor version, use `~/.cursor/mcp.json` (user level).

### Codex

`~/.codex/config.toml` (or `<repo>/.codex/config.toml` for trusted projects):

```toml
[mcp_servers.radzen-blazor]
url = "https://app.radzen.com/mcp"
env_http_headers = { "X-Radzen-Key" = "RADZEN_MCP_KEY" }
```

## 3. Verify

```text
pwsh .speckit/radzen/tools/speckit-radzen.ps1 mcp-check          # configuration only
pwsh .speckit/radzen/tools/speckit-radzen.ps1 mcp-check -Probe   # calls the endpoint with RADZEN_MCP_KEY
```

Then ask the agent: "Which Radzen MCP tools do you have?" It must list the `search` tool of `radzen-blazor`. Record the result for the feature:

```text
pwsh .speckit/radzen/tools/speckit-radzen.ps1 state -Feature 001 -McpAvailability available
```

| Status | Meaning / action |
|---|---|
| `available` | Key accepted |
| `configured` | Config present; not probed (or key only in the client prompt) |
| `not-configured` | Add a client configuration |
| `unauthorized` | Wrong key or licence expired |
| `quota-exhausted` | Trial limit reached — reuse evidence, see fallback matrix |
| `unreachable` | Network/proxy — see fallback matrix |
| `secret-in-repo` | Remove and rotate the key |

## 4. Without MCP

The agent follows `core/mcp/fallback-matrix.md`: project usage and the compiler are acceptable evidence; documentation needs your approval (`evidence add -Source docs -FallbackApproved -FallbackReason "…"`); model knowledge alone is never enough.
