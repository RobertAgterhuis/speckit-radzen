# Data Presentation

Before building collection UI, determine: expected cardinality (numbers, not adjectives), whether the backend supports paging/filtering/sorting, where each operation runs, selection/editing needs, and mobile behaviour (P-10). Record it in the spec's *Data volume* section.

## Rules

- Do not fetch all records by default for potentially unbounded data (AP-DAT-01/02, AP-RDZ-02).
- For server-side data use `LoadData` + `Count` + `IsLoading` (AP-RDZ-03/14). Map `LoadDataArgs` paging values to the repository's query/contract in one place (a small mapping function is easy to unit test).
- Never forward the raw filter expression string to a server query or URL (AP-RDZ-04). Translate structured filter values into typed parameters and validate fields/operators on the server.
- Project to DTOs with only the fields the screen shows (AP-SEC-08).
- Keep sort/filter capabilities honest: only enable grid sorting/filtering for columns the backend supports.
- Use `EmptyText` (or the repository's empty-state component) for no-data states.
- After create/update/delete, reload once (`Reload()`), not per item (AP-RDZ-08).
- Virtualization is for long scrolling lists; paging is simpler and usually preferred for business grids.

## Formatting

Use the repository's culture and formatting helpers. Dates, numbers and currency follow the user's culture unless the spec says otherwise.
