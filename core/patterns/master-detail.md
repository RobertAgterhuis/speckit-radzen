# Pattern: Master–Detail

**Use when:** Selecting an item in a list shows or edits its details.

**Avoid when:** Two grids side by side on narrow screens.

## Spec questions

- Deep link to the selected item (URL)?
- Does selection persist across paging/filtering?
- Is detail loaded independently (and authorized separately)?
- No-selection state?
- Mobile: stack or navigate?

## Implementation guidance

Follow the analogous feature first (P-02). Confirm every Radzen member through MCP (P-15).

- Master: `data-grid.md` with selection; detail loads by id through the repository service.
- Keep selection in the URL when the repository uses routable details.
- Detail has its own loading/failure/forbidden states.
- Use `RadzenSplitter` or `RadzenRow`/`RadzenColumn` for wide layouts, stacked or routed on small screens.

## MCP query recipes

- `RadzenDataGrid selection SelectionMode RowSelect @bind-Value`
- `RadzenSplitter panes responsive`

## UI states

No selection, detail loading, detail not found, detail forbidden.

## Responsive and accessibility

Stack or navigate on narrow screens (AP-RSP-02).

## Related anti-patterns

[AP-RSP-02](../antipatterns/rsp.md#ap-rsp-02), [AP-SEC-01](../antipatterns/sec.md#ap-sec-01), [AP-PERF-01](../antipatterns/perf.md#ap-perf-01)

## Test scenarios

- Selecting a row loads its detail once.
- Unauthorized detail is refused server-side.
