# Accessibility

Baseline for changed UI (P-09). This baseline does not by itself prove WCAG conformance.

- Everything is keyboard operable; focus order follows the visual order; no positive `tabindex` (AP-A11Y-05).
- Focus is visible and managed in dialogs (moves in, returns on close).
- Inputs have programmatic labels (`RadzenFormField`, `RadzenLabel Component=…`, or `aria-label`) (AP-A11Y-04).
- Icon-only buttons have an accessible name (AP-A11Y-01).
- Images have `alt` (empty for decorative) (AP-A11Y-03).
- Validation messages are text, associated with fields, and understandable.
- Colour is never the only carrier of meaning (AP-A11Y-02).
- Headings form a sensible outline (`RadzenText TagName=…`).
- Dynamic updates (loading, results count, notifications) remain perceivable.
- Prefer native semantics and Radzen's built-in accessibility features; verify component keyboard support through MCP when the feature depends on it.
