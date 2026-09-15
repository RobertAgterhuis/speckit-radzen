# Pattern: Lookup / Cascading Dropdown

**Use when:** Choosing a value from a (possibly large) reference set; dependent choices.

**Avoid when:** Loading every option up front for large sets.

## Spec questions

- Size of each option set?
- Filtering needs?
- Dependencies between dropdowns?
- Allow clear / null?

## Implementation guidance

Follow the analogous feature first (P-02). Confirm every Radzen member through MCP (P-15).

- Large sets: `RadzenDropDown` with `LoadData` + `AllowFiltering` (+ `Count` for virtual/paged), or `RadzenAutoComplete`.
- Cascading: on parent `Change`, reset the child value and reload its options.
- Bind the id, not the entity.

## MCP query recipes

- `RadzenDropDown LoadData AllowFiltering Count for large lists`
- `Radzen cascading RadzenDropDown Change reload dependent`
- `RadzenAutoComplete LoadData MinLength FilterDelay`

## UI states

Loading options, no options, selected value no longer valid.

## Responsive and accessibility

Full-width on small screens; accessible label.

## Related anti-patterns

[AP-DAT-02](../antipatterns/dat.md#ap-dat-02), [AP-PERF-02](../antipatterns/perf.md#ap-perf-02), [AP-A11Y-04](../antipatterns/a11y.md#ap-a11y-04)

## Test scenarios

- Changing the parent clears the child.
- Filtering requests only matching options.
