# Radzen MCP Integration

Spec Kit Radzen is MCP-first: agents query the **Radzen Blazor MCP** for current component knowledge and log every answer as evidence. The rules are in `core/mcp/`; this folder contains client configuration templates.

## Templates

| Client | Template | Where it goes | Secret handling |
|---|---|---|---|
| Claude Code | `templates/claude-code.mcp.json` | `<repo>/.mcp.json` (project scope) | `${RADZEN_MCP_KEY}` environment expansion |
| VS Code (GitHub Copilot) | `templates/vscode.mcp.json` | `<repo>/.vscode/mcp.json` | `${input:radzen-key}` secure prompt, stored by VS Code |
| Visual Studio 2022 17.14+ | `templates/visual-studio.mcp.json` | `%USERPROFILE%\.mcp.json` or `<solution>\.vs\mcp.json` (both outside source control) | `${input:radzen-key}` prompt; if your version does not prompt, put the key in that user-level file only |
| Cursor | `templates/cursor.mcp.json` | `<repo>/.cursor/mcp.json` | `${env:RADZEN_MCP_KEY}` |
| Codex | `templates/codex.config.toml` | `~/.codex/config.toml`, or `<repo>/.codex/config.toml` (trusted projects) | `env_http_headers` reads `RADZEN_MCP_KEY` |

Install them with the installer (`-McpClient ClaudeCode,VSCode,Cursor,Codex`) or copy them by hand. The installer never writes a key and never overwrites an existing MCP configuration; it merges the `radzen-blazor` server entry when the file exists.

## Set the key

```powershell
# Windows, persistent for the current user
[Environment]::SetEnvironmentVariable('RADZEN_MCP_KEY', '<your key>', 'User')
```

```bash
# macOS / Linux (add to your shell profile)
export RADZEN_MCP_KEY='<your key>'
```

Restart the IDE/agent after setting it.

## Check

```text
pwsh .speckit/radzen/tools/speckit-radzen.ps1 mcp-check          # static check, no network
pwsh .speckit/radzen/tools/speckit-radzen.ps1 mcp-check -Probe   # also calls the endpoint with RADZEN_MCP_KEY
```

Results: `available`, `configured`, `not-configured`, `unreachable`, `unauthorized`, `secret-in-repo`.

## Known client caveats

- Header variable expansion has had bugs in some client versions (for example Claude Code and Cursor issues about `${VAR}` in `headers`). If the server returns 401 although the variable is set, configure the server at **user** level (`claude mcp add --scope user --transport http radzen-blazor https://app.radzen.com/mcp --header "X-Radzen-Key: <key>"`, or `~/.cursor/mcp.json`) — never in the repository.
- Claude Code asks for approval before using project-scoped servers.

See `docs/mcp-setup.md` for the full guide.
