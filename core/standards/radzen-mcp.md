# Radzen MCP Standard

Summary of the MCP-first rules. The full workflow is in `../mcp/`.

- Use the Radzen Blazor MCP (`search`) for component selection, properties, events, callbacks, enums, binding, services, templates and supported patterns — before writing code (`../mcp/mcp-workflow.md`).
- Query narrowly: exact component names, data shape, required interaction, installed version (`../mcp/query-playbook.md`).
- Record every answer that informs code as `MCP-###` evidence (`speckit-radzen evidence add`).
- Verification precedence: installed package/compiler → project-local usage → Radzen MCP → official docs → model knowledge (never sufficient alone).
- Conflicts and unavailability: `../mcp/fallback-matrix.md`.
- Radzen Blazor Studio MCP may scaffold or edit only within approved scope (`../mcp/studio-guardrails.md`).
- Never commit MCP licence keys (ADR-0005).
