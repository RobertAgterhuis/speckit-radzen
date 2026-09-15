# Pattern: Form

**Use when:** Collecting and submitting structured input.

**Avoid when:** Binding persistence entities directly; long multi-step processes in one form (use wizard).

## Spec questions

- Model/contract and create vs edit mode?
- Required fields and validation source (client + server)?
- Submit operation and its authorization?
- Cancel behaviour and unsaved-changes handling?
- Success and failure behaviour?
- Concurrency?

## Implementation guidance

Follow the analogous feature first (P-02). Confirm every Radzen member through MCP (P-15).

- Use the repository form abstraction; otherwise `RadzenTemplateForm TItem=<ViewModel>` with `Submit`.
- Inputs inside `RadzenFormField` (label) with `Name`; validators reference the input name.
- Submit button `ButtonType.Submit` with `IsBusy` during the call.
- Map server validation errors to fields when the repository does.
- Nullable `TValue` for optional numeric/date inputs.

## MCP query recipes

- `RadzenTemplateForm TItem Submit InvalidSubmit with RadzenFormField`
- `Radzen validators RadzenRequiredValidator RadzenLengthValidator Component name`
- `RadzenButton IsBusy ButtonType Submit`

## UI states

Pristine, dirty, submitting, success, validation failure, operational failure, read-only.

## Responsive and accessibility

Single column on small screens; labels stay visible; error text wraps.

## Related anti-patterns

[AP-FRM-01](../antipatterns/frm.md#ap-frm-01), [AP-FRM-02](../antipatterns/frm.md#ap-frm-02), [AP-FRM-03](../antipatterns/frm.md#ap-frm-03), [AP-FRM-05](../antipatterns/frm.md#ap-frm-05), [AP-A11Y-04](../antipatterns/a11y.md#ap-a11y-04), [AP-SEC-03](../antipatterns/sec.md#ap-sec-03)

## Test scenarios

- Invalid input shows field messages and does not submit.
- Double click submits once.
- Server rejection is shown safely.
