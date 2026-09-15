# Pattern: Search as You Type

**Use when:** Filtering results while the user types.

**Avoid when:** Calling the server on every keystroke.

## Spec questions

- Minimum length?
- Debounce interval?
- What happens to in-flight requests?
- Empty query behaviour?

## Implementation guidance

Follow the analogous feature first (P-02). Confirm every Radzen member through MCP (P-15).

- Search on change (Enter/blur) when that is acceptable; otherwise debounce and cancel the previous request.
- Trim input; ignore unchanged queries; reset paging to the first page.

## MCP query recipes

- `RadzenTextBox Change vs @oninput`
- `RadzenAutoComplete FilterDelay MinLength`

## UI states

Typing, searching, results, no results, failure.

## Responsive and accessibility

Search box full width on small screens; accessible label.

## Related anti-patterns

[AP-PERF-02](../antipatterns/perf.md#ap-perf-02), [AP-A11Y-04](../antipatterns/a11y.md#ap-a11y-04)

## Test scenarios

- Rapid typing results in one request for the final query.
