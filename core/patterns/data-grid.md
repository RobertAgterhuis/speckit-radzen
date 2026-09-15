# Pattern: Data Grid

**Use when:** Users compare structured rows and need sorting, filtering, paging, selection, row actions or inline editing.

**Avoid when:** A handful of static items (use a list), card-like content, or when the backend cannot page an unbounded set (surface the gap instead).

## Spec questions

- Columns, their order and which are essential on mobile?
- Row identity and default sort?
- Expected rows now/later; bounded?
- Which operations does the backend support (paging, sorting, filtering)?
- Row actions and their authorization?
- Selection (single/multiple) and what it drives?
- Empty, loading and failure behaviour?

## Implementation guidance

Follow the analogous feature first (P-02). Confirm every Radzen member through MCP (P-15).

- Reuse the repository grid wrapper if one exists (`radzen.wrappers`).
- Server data: `LoadData` + `Count` + `IsLoading`; bind `Data` to the current page only.
- Map `LoadDataArgs` (paging, sort, structured filters) to the repository query in one testable function; never forward the raw filter string.
- Enable `AllowSorting`/`AllowFiltering` only for columns the backend supports.
- Set `EmptyText`; reload once after mutations (`Reload()`); return to page 1 after filter changes.
- Keep templates cheap: no service calls per row.

## MCP query recipes

- `RadzenDataGrid LoadData server-side paging sorting filtering with Count and IsLoading for TItem <Type>`
- `RadzenDataGrid LoadDataArgs Filters and Sorts to build a typed server query`
- `RadzenDataGridColumn Template FormatString Visible Width responsive`

## UI states

Loading (IsLoading), empty (EmptyText), failure (repository error UI/notification), forbidden (hide actions + server policy).

## Responsive and accessibility

Choose horizontal scroll, priority columns or a card view for small screens; avoid large fixed widths; icon-only row actions need accessible names.

## Related anti-patterns

[AP-RDZ-02](../antipatterns/rdz.md#ap-rdz-02), [AP-RDZ-03](../antipatterns/rdz.md#ap-rdz-03), [AP-RDZ-04](../antipatterns/rdz.md#ap-rdz-04), [AP-RDZ-08](../antipatterns/rdz.md#ap-rdz-08), [AP-RDZ-14](../antipatterns/rdz.md#ap-rdz-14), [AP-PERF-01](../antipatterns/perf.md#ap-perf-01), [AP-RSP-01](../antipatterns/rsp.md#ap-rsp-01), [AP-A11Y-01](../antipatterns/a11y.md#ap-a11y-01)

## Test scenarios

- Paging maps skip/top correctly (unit).
- Filter change returns to the first page.
- Empty result shows the empty text.
- Row action is rejected server-side for an unauthorized user (integration).
