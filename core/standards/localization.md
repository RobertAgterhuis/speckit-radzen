# Localization

Applies when the profile reports localization (`architecture.localization`).

- Use the repository's localizer (`IStringLocalizer<T>` or its wrapper) for every user-visible string, including grid column titles, `EmptyText`, validator texts and dialog titles.
- Format dates, numbers and currency with the current culture; Radzen inputs take format strings (`DateFormat`, `Format`) — follow the repository's conventions.
- Check long translations at constrained widths (see `responsive-design.md`).
- Radzen's built-in texts (pager, filter menu) can be localized through component parameters or the repository's approach; verify the parameters through MCP for the installed version.
