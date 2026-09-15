# Pattern: Tree / Hierarchical Data

**Use when:** Navigating or selecting within a hierarchy.

**Avoid when:** Loading an entire deep hierarchy up front.

## Spec questions

- Depth and size?
- Lazy loading?
- Selection/check behaviour?

## Implementation guidance

Follow the analogous feature first (P-02). Confirm every Radzen member through MCP (P-15).

- `RadzenTree` with on-expand loading for large trees; items carry an id and a has-children flag from the server.

## MCP query recipes

- `RadzenTree Data Expand LoadData lazy loading RadzenTreeLevel`

## UI states

Node loading, empty children, failure on expand.

## Responsive and accessibility

Indentation and touch targets remain usable on small screens.

## Related anti-patterns

[AP-DAT-02](../antipatterns/dat.md#ap-dat-02), [AP-PERF-01](../antipatterns/perf.md#ap-perf-01)

## Test scenarios

- Expanding a node requests only its children.
