# Standards

Engineering standards for Radzen Blazor work. They apply unless the repository has an established convention that says otherwise (P-02); repository-local standards live in `.speckit/radzen/local/standards/`.

Version-specific Radzen details are **not** hardcoded here. Where a standard names a Radzen member, confirm it for the installed version through the MCP loop (`mcp/mcp-workflow.md`) before relying on it.

| Standard | Read when |
|---|---|
| `radzen-setup.md` | the feature touches services, layout host, theme, scripts or render modes |
| `component-selection.md` | choosing components |
| `data-presentation.md` | showing collections |
| `forms-validation.md` | any input |
| `dialogs-notifications.md` | dialogs, confirmations, toasts |
| `state-error-handling.md` | loading, failures, state |
| `authorization-security.md` | any feature with data or actions |
| `responsive-design.md` | any changed screen |
| `accessibility.md` | any changed screen |
| `performance.md` | collections, frequent requests, heavy templates |
| `localization.md` | the repository is localized |
| `testing.md` | writing tests |
| `radzen-mcp.md` | using the Radzen MCP (summary; details in `../mcp/`) |
