# Pattern: Wizard / Steps

**Use when:** Multi-step input where later steps depend on earlier ones.

**Avoid when:** Short forms (use one form) or steps that are independent tabs.

## Spec questions

- Steps and their validation?
- Can users go back?
- Is progress saved between steps?
- Final submit vs per-step saves?

## Implementation guidance

Follow the analogous feature first (P-02). Confirm every Radzen member through MCP (P-15).

- `RadzenSteps` with one form model; validate the current step before advancing.
- Submit once at the end unless the spec requires drafts.
- Keep step state in the component or the repository state pattern.

## MCP query recipes

- `RadzenSteps validation between steps NextStep PreviousStep`
- `RadzenSteps with RadzenTemplateForm`

## UI states

Per step: invalid, valid; final: submitting, success, failure.

## Responsive and accessibility

Step titles wrap or collapse on small screens.

## Related anti-patterns

[AP-FRM-02](../antipatterns/frm.md#ap-frm-02), [AP-FRM-05](../antipatterns/frm.md#ap-frm-05)

## Test scenarios

- Cannot advance with invalid input.
- Final submit sends the combined model once.
