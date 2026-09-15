# Responsive Design

Review every changed screen at constrained widths (at least 375 px, 768 px and a desktop width) (P-09).

- Use layout components (`RadzenStack`, `RadzenRow`/`RadzenColumn` with size breakpoints) and the repository's breakpoints/theme variables.
- Dense grids: choose deliberately between horizontal scroll, priority columns, hiding secondary columns at small sizes, a card/list alternative, or detail expansion. Avoid large fixed pixel widths (AP-RSP-01/04).
- Dialogs: relative or capped widths (AP-RSP-03); consider side dialogs or full pages on small screens.
- Master-detail: stack or navigate on narrow screens (AP-RSP-02).
- Allow long and localized strings to wrap; avoid fixed heights for text.
- Touch targets remain usable; do not rely on hover.
