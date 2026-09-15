# Pattern: Navigation and Layout

**Use when:** Adding pages to menus or changing layout regions.

**Avoid when:** Changing the global layout for a single feature without a plan entry.

## Spec questions

- Where does the page appear in navigation?
- Who may see the menu entry (UX) — and is the page itself protected?
- Responsive sidebar behaviour?

## Implementation guidance

Follow the analogous feature first (P-02). Confirm every Radzen member through MCP (P-15).

- Add menu entries in the repository navigation component (`RadzenPanelMenu` or similar); hide entries for UX only — protect the page with `[Authorize]`/policies.
- Layout changes (`RadzenLayout`, header, sidebar, component host) are global: plan them as their own slice.

## MCP query recipes

- `RadzenLayout RadzenSidebar RadzenPanelMenu responsive toggle`

## UI states

Active item, collapsed sidebar, unauthorized page access.

## Responsive and accessibility

Sidebar collapses on small screens; menu reachable by keyboard.

## Related anti-patterns

[AP-SEC-01](../antipatterns/sec.md#ap-sec-01), [AP-RDZ-13](../antipatterns/rdz.md#ap-rdz-13)

## Test scenarios

- Hidden menu entry does not grant or deny page access; the page policy does.
