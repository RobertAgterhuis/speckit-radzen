# Pattern: CRUD Management Screen

**Use when:** A screen to list, create, update and/or delete records of one type.

**Avoid when:** Assuming all four operations are required; discover and specify each independently.

## Spec questions

- Which of Read/Create/Update/Delete are required, for whom?
- Delete semantics: hard/soft, cascade, undo, audit?
- Edit model: page, dialog or inline (repository convention)?
- Validation rules and where they are enforced?
- Concurrency: last-write-wins or conflict detection?

## Implementation guidance

Follow the analogous feature first (P-02). Confirm every Radzen member through MCP (P-15).

- List: follow `data-grid.md`.
- Create/Update: follow `form.md`; page vs dialog vs inline per the analogous feature.
- Delete: confirmation (`DialogService.Confirm`), server-side authorization, explicit failure handling, single reload afterwards.
- Every mutation goes through the repository service/API — never a DbContext in the component.

## MCP query recipes

- `Radzen DialogService Confirm options and return value`
- `RadzenDataGrid inline edit EditRow UpdateRow CancelEditRow`
- `RadzenTemplateForm Submit with validators`

## UI states

Per operation: submitting, success feedback, validation failure, operational failure, forbidden, concurrency conflict.

## Responsive and accessibility

Action buttons wrap on small screens; destructive actions are clearly labelled.

## Related anti-patterns

[AP-SEC-01](../antipatterns/sec.md#ap-sec-01), [AP-FRM-01](../antipatterns/frm.md#ap-frm-01), [AP-FRM-02](../antipatterns/frm.md#ap-frm-02), [AP-RDZ-07](../antipatterns/rdz.md#ap-rdz-07), [AP-ARC-05](../antipatterns/arc.md#ap-arc-05), [AP-RDZ-08](../antipatterns/rdz.md#ap-rdz-08)

## Test scenarios

- Each operation succeeds for an authorized user.
- Each operation is denied server-side for an unauthorized user.
- Validation errors appear next to fields.
- Cancelled delete changes nothing.
