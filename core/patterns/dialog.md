# Pattern: Dialog

**Use when:** Confirmation, short create/edit, small selection workflows, contextual details.

**Avoid when:** Long multi-step workflows, large data exploration, content that needs deep linking.

## Spec questions

- What result does the dialog return?
- What happens on dismiss?
- Width strategy on small screens?
- Is there an existing dialog wrapper/options preset?

## Implementation guidance

Follow the analogous feature first (P-02). Confirm every Radzen member through MCP (P-15).

- Use the repository wrapper/presets; otherwise `DialogService.OpenAsync<TComponent>(title, parameters, options)`.
- Pattern-match the result: `if (await ... is TResult r)`.
- Close from inside with `DialogService.Close(result)`.
- Confirm destructive actions with `DialogService.Confirm`; only `true` means yes.
- The layout must host `<RadzenComponents />` with an interactive render mode.

## MCP query recipes

- `Radzen DialogService OpenAsync with parameters and DialogOptions`
- `Radzen DialogService Close result`
- `Radzen DialogService Confirm return value`

## UI states

Opening, busy inside the dialog, validation inside the dialog, dismissed, completed.

## Responsive and accessibility

Relative/capped widths; consider a side dialog or page on mobile; focus moves into the dialog and back.

## Related anti-patterns

[AP-RDZ-05](../antipatterns/rdz.md#ap-rdz-05), [AP-RDZ-07](../antipatterns/rdz.md#ap-rdz-07), [AP-RDZ-13](../antipatterns/rdz.md#ap-rdz-13), [AP-RSP-03](../antipatterns/rsp.md#ap-rsp-03)

## Test scenarios

- Dismiss returns no changes.
- Completed dialog returns the result and the caller refreshes once.
