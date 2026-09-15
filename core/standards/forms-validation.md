# Forms and Validation

Follow the repository's established form and validation model (P-02, P-06).

## Rules

- Bind forms to view models/DTOs, never to persistence entities when the repository uses contracts (AP-FRM-01).
- Client validation improves UX; the trusted layer enforces business rules (AP-FRM-03). The plan names the server validation for each rule.
- `RadzenTemplateForm` needs validators — Radzen validators (`RadzenRequiredValidator`, `RadzenLengthValidator`, `RadzenRegexValidator`, `RadzenCompareValidator`, `RadzenNumericRangeValidator`, …) or the DataAnnotations validator used by the repository (AP-FRM-05). Validators reference inputs by `Name`/`Component`.
- Show actionable messages next to the field. Map server validation errors (ProblemDetails `errors`) back to fields when the repository does.
- Prevent duplicate submission: disable the submit button while busy (`IsBusy`/`Disabled`) (AP-FRM-02).
- Handle submit outcomes intentionally: success (navigate/notify/close), validation failure (field messages), operational failure (safe message + log), concurrency conflict (reload/merge per spec).
- Preserve nullability semantics (`TValue` of `RadzenNumeric`/`RadzenDatePicker` nullable when the field is optional).
- Destructive actions need explicit confirmation and server-side authorization.

## Layout

Use `RadzenFormField` (floating/visible label) or `RadzenLabel` associated with the input for accessible names (AP-A11Y-04). Group related fields; keep one column on small screens.
