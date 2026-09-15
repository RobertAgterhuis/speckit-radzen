# Pattern: Dashboard

**Use when:** Summarized metrics and charts with drill-down.

**Avoid when:** Loading raw datasets to aggregate in the browser.

## Spec questions

- Metric definitions and data freshness?
- Time range and filters?
- Authorization per widget?
- Drill-down targets?
- No-data semantics per widget?

## Implementation guidance

Follow the analogous feature first (P-02). Confirm every Radzen member through MCP (P-15).

- Aggregate on the server; return only metric values/series.
- Each widget loads independently with its own loading/failure state.
- Charts: `RadzenChart` with the appropriate series; axis formatting per culture.
- Stack widgets responsively (`RadzenRow`/`RadzenColumn` sizes).

## MCP query recipes

- `RadzenChart RadzenColumnSeries CategoryProperty ValueProperty axis formatting`
- `RadzenCard layout RadzenRow RadzenColumn SizeMD`

## UI states

Per widget: loading, empty (no data for range), failure, forbidden, stale (show freshness).

## Responsive and accessibility

Widgets stack on small screens; charts have text alternatives or data tables.

## Related anti-patterns

[AP-DAT-03](../antipatterns/dat.md#ap-dat-03), [AP-A11Y-02](../antipatterns/a11y.md#ap-a11y-02), [AP-PERF-01](../antipatterns/perf.md#ap-perf-01)

## Test scenarios

- Metric values match server aggregation for a fixed dataset.
- A failing widget does not break the others.
