# Pattern: Inline Grid Editing

**Use when:** Quick edits of a few fields directly in a grid, when the repository uses it.

**Avoid when:** Complex validation or many fields (use a dialog or page).

## Spec questions

- Which columns are editable?
- One row at a time?
- Validation and save per row?
- Cancel behaviour?

## Implementation guidance

Follow the analogous feature first (P-02). Confirm every Radzen member through MCP (P-15).

- Use the grid edit API (edit/update/cancel row) with `EditTemplate` per editable column.
- Validate within the row; save through the service; reload or update the row once.
- Only one row in edit mode unless the spec says otherwise.

## MCP query recipes

- `RadzenDataGrid EditRow UpdateRow CancelEditRow RowUpdate EditMode`

## UI states

Editing, saving, validation failure in row, save failure, cancelled.

## Responsive and accessibility

Inline editing is hard on small screens; offer a dialog alternative when mobile matters.

## Related anti-patterns

[AP-FRM-01](../antipatterns/frm.md#ap-frm-01), [AP-FRM-02](../antipatterns/frm.md#ap-frm-02), [AP-RDZ-08](../antipatterns/rdz.md#ap-rdz-08)

## Test scenarios

- Cancel restores original values.
- Save failure keeps the row in edit mode with a message.
