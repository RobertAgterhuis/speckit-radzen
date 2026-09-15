# Test Scenarios: Customer search

| ID | Covers | Level | Scenario | Expected result | Automated in |
|---|---|---|---|---|---|
| TS-001 | AC-001 | unit | first page args (skip 0, top 20) map to a query | Skip 0, Take 20 | CustomerQueryTests.First_page_maps_skip_and_take |
| TS-002 | AC-002 | unit | page 2 args (skip 20, top 20) against the service | customers 21–40, total 250 | CustomerQueryTests.Second_page_returns_items_21_to_40 |
| TS-003 | AC-003 | unit | name filter "customer 00" | 9 results | CustomerQueryTests.Name_filter_is_trimmed_and_applied |
| TS-004 | AC-004 | manual | search "zzz" in the browser | grid shows "No customers found." | manual |

## State coverage

| UI state | Scenario |
|---|---|
| Loading | TS-004 (observe loader while typing a search) |
| Empty | TS-004 |
| Operational failure | manual: stop the app mid-request; default error UI appears |
| Forbidden | n/a (no authorization) |

## Manual verification

- 375 px: search box full width, grid scrolls horizontally, pager usable by touch.
- Keyboard: Tab reaches the search box, Enter/blur triggers the search, the pager is reachable.
