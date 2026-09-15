# Component Selection

Choose by required interaction, local patterns, cardinality, editing model, responsiveness, accessibility, performance and maintainability (P-05).

## Reuse order

1. An existing repository component or wrapper (see `radzen.wrappers` in the profile, and the analogous feature).
2. A suitable Radzen component, verified through MCP.
3. A composition of supported Radzen primitives (`RadzenStack`, `RadzenRow`/`RadzenColumn`, `RadzenCard`, `RadzenFormField`).
4. A custom component — only with a written reason in the plan.

## Typical choices

| Need | Usually | Avoid |
|---|---|---|
| Tabular data with paging/sorting/filtering/selection | `RadzenDataGrid` | a grid for 3–5 static items |
| Simple list or cards | `RadzenDataList`, `@foreach` with `RadzenCard` | `RadzenDataGrid` without columns that matter |
| Pick one from a large set | `RadzenDropDown` with `LoadData`/filtering, `RadzenAutoComplete`, `RadzenDropDownDataGrid` | loading every option up front |
| Form layout | `RadzenTemplateForm` + `RadzenFormField` / `RadzenRow` | hand-built label/input markup |
| Short confirmation | `DialogService.Confirm` | a custom modal |
| Short edit | dialog (`OpenAsync<T>`) or inline grid edit, following the repository | long multi-step workflows in a dialog |
| Multi-step input | `RadzenSteps` | nested dialogs |
| Hierarchy | `RadzenTree` (lazy load for large trees) | recursive grids |
| Scheduling | `RadzenScheduler` | a grid of dates |
| Charts | `RadzenChart` (+ series) with server-side aggregation | client-side aggregation of raw rows |

## Wrappers

Create a wrapper only when it enforces a repository convention (defaults, paging contract, error handling) across several screens. A wrapper around one component with pass-through parameters adds indirection without value (AP-ARC-02).
