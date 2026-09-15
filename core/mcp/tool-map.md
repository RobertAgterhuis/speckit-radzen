# MCP Tool Map

- **Last verified:** 2026-09-15 against the public Radzen documentation.
- Re-verify when a client shows different tool names; update this file and `mcp/templates/`.

## Radzen Blazor MCP

| Property | Value |
|---|---|
| Endpoint | `https://app.radzen.com/mcp` |
| Transport | Streamable HTTP |
| Authentication | HTTP header `X-Radzen-Key: <license key>` |
| Conventional server name | `radzen-blazor` |
| Licensing | Free trial (limited requests); unlimited with Radzen Blazor Pro / Team |
| Tools | `search` — natural-language query; returns markdown with component APIs (properties, events, enum values, binding patterns), code samples and implementation guides; also covers ready-made templates (CRUD, master-detail, dashboards, forms, schedulers, wizards) |

How the tool appears in an agent's tool list depends on the client, for example `mcp__radzen-blazor__search` (Claude Code) or `radzen-blazor/search`. Agents must confirm the tool is actually listed before claiming MCP is available.

### Query guidance from Radzen

- Use the exact component name (`RadzenDataGrid`, not "grid").
- Give the data model context (entity properties, relationships).
- Build incrementally: one component or concern per query.
- Mention "Radzen" explicitly.

## Radzen Blazor Studio MCP

| Property | Value |
|---|---|
| Runs | Locally, provided by Radzen Blazor Studio while a project is open |
| Capabilities | Edit/insert/configure components; switch themes and adjust colours; connect data sources, infer models and create services; scaffold pages, layouts, authentication and localization |
| Setup | Per client and OS, see the Radzen Blazor Studio documentation (`mcp-server` page) |
| Tool names | Take them from the client's tool list at runtime; do not hardcode |

Use only under `studio-guardrails.md`.

## Other sources that count as evidence

| Source | Rank | How to cite |
|---|---|---|
| Compiler / installed package | 1 | Build output of G5, or `obj/project.assets.json` package version, or XML docs in the NuGet package |
| Project-local usage | 2 | `file:line` of existing code using the same member in this repository |
| Radzen Blazor MCP | 3 | Query text + summary of the answer |
| Official docs (blazor.radzen.com, radzen.com/documentation) | 4 | URL |
| Model knowledge | 5 | Not accepted on its own |
