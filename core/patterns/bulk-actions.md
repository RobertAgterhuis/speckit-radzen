# Pattern: Bulk Actions

**Use when:** Applying one action to many selected rows.

**Avoid when:** Per-item round trips with a reload after each.

## Spec questions

- Maximum selection size?
- Partial failure handling?
- Authorization per item?
- Confirmation text?

## Implementation guidance

Follow the analogous feature first (P-02). Confirm every Radzen member through MCP (P-15).

- Multiple selection in the grid; one batch call to the backend when available; one reload afterwards.
- Report partial failures per item.
- Confirm destructive bulk actions with counts.

## MCP query recipes

- `RadzenDataGrid SelectionMode Multiple @bind-Value selected items`

## UI states

Nothing selected (actions disabled), running (progress), partial failure, success.

## Responsive and accessibility

Selection controls and action bar usable on touch devices.

## Related anti-patterns

[AP-RDZ-08](../antipatterns/rdz.md#ap-rdz-08), [AP-RND-06](../antipatterns/rnd.md#ap-rnd-06), [AP-SEC-01](../antipatterns/sec.md#ap-sec-01)

## Test scenarios

- Bulk delete of N items makes one batch call and one reload.
- Unauthorized items are rejected server-side and reported.
