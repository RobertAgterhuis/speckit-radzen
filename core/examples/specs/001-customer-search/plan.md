# Implementation Plan: Customer search

- **Feature:** 001-customer-search
- **Spec:** `spec.md` · **Evidence:** `mcp-evidence.md` · **Tests:** `test-scenarios.md`

## Context

Add a `/customers` page to Sample.Web that shows customers in a server-paged RadzenDataGrid with a name search box. The existing `ICustomerService` already pages and filters; only UI and tests change.

## Relevant repository evidence

- src/Sample.Web/Customers/ICustomerService.cs:5 — `GetPageAsync(skip, take, nameContains)` returns items and total.
- src/Sample.Web/Components/App.razor:10 — global InteractiveServer render mode.
- src/Sample.Web/Components/Layout/MainLayout.razor:2 — `<RadzenComponents />` host present.

## Constitution check

| Principle | Status | Notes |
|---|---|---|
| P-01 Repository Awareness | complies | detect + discovery.md |
| P-02 Architecture Preservation | complies | uses existing service, no new layers |
| P-03 Radzen MCP First | complies | MCP-001…MCP-003 |
| P-04 Version Awareness | complies | Radzen 7.x from profile |
| P-05 Requirement-Driven Component Selection | complies | grid needed for paging + columns |
| P-06 Separation of Concerns | complies | query mapping in a small helper, no business rules in UI |
| P-07 Security Boundary | n/a | no authentication in sample app (spec non-goal) |
| P-08 Explicit UI States | complies | loading, empty, error per spec |
| P-09 Responsive and Accessible Baseline | complies | labelled search, horizontal scroll |
| P-10 Data-Volume Awareness | complies | server paging via LoadData |
| P-11 Small Vertical Slices | complies | S-01 paging, S-02 search |
| P-12 Verification | complies | G5/G6 per slice |
| P-13 Stop Conditions | complies | none triggered |
| P-14 Evidence Over Assumption | complies | evidence cited |
| P-15 Recorded MCP Evidence | complies | mcp-evidence.json |
| P-16 Render-Mode Correctness | complies | inherits global InteractiveServer; LoadData not raised during prerender is acceptable (grid loads after first interactive render) |

## Layer impact

| Layer | Impact | Areas / files |
|---|---|---|
| UI | add | src/Sample.Web/Components/Pages/Customers.razor, Customers.razor.cs |
| Shared UI | no change | — |
| Contracts | no change | — |
| Application / services | add | src/Sample.Web/Customers/CustomerQuery.cs (args mapping) |
| API / endpoints | no change | — |
| Middleware | no change | — |
| Authorization | no change | — |
| Persistence | no change | — |
| Tests | add | tests/Sample.Web.Tests/CustomerQueryTests.cs |
| Configuration | no change | — |

## Approved dependency changes

- None.

## Component strategy

| UI element | Component | Reuse level | Reason | Evidence |
|---|---|---|---|---|
| Customer list | RadzenDataGrid | Radzen | server paging with pager and columns | MCP-001 |
| Search box | RadzenTextBox in RadzenFormField | Radzen | labelled input with change event | MCP-002 |

## Radzen MCP verification

| Component / service | Members | Evidence |
|---|---|---|
| RadzenDataGrid | LoadData, Count, IsLoading, AllowPaging, PageSize, EmptyText, FirstPage | MCP-001 |
| RadzenTextBox | Change, @bind-Value | MCP-002 |
| LoadDataArgs | Skip, Top | MCP-003 |

## Render mode

| Page / component | Render mode | Prerendering | Handling |
|---|---|---|---|
| Pages/Customers.razor | InteractiveServer (inherited from Routes) | on | LoadData runs after the first interactive render; no prerender data load, so no double loading |

## Security model

| Actor | Operation | Enforcement point | Data exposed | Forbidden behaviour |
|---|---|---|---|---|
| Sales user | read customer list | none (non-goal) | name, city | n/a |

## Data flow

`LoadData(args)` → `CustomerQuery.From(args, nameFilter)` → `ICustomerService.GetPageAsync(skip, take, name)` → `Data` = page items, `Count` = total. The search box `Change` sets the filter and calls `grid.FirstPage(true)`, which triggers `LoadData` for page 1.

## UI states

`IsLoading` is true during the service call; `EmptyText="No customers found."`; errors use the default Blazor error UI (repository convention).

## Responsive and accessibility strategy

Grid inside `RadzenStack`; the grid scrolls horizontally on narrow screens. The search input sits in `RadzenFormField Text="Search by name"` (visible label). No icon-only buttons.

## Testing strategy

xUnit unit tests for `CustomerQuery` (paging and filter mapping) and the existing service tests. Page rendering is verified manually at 375 px and 1280 px (see test-scenarios.md).

## Vertical slices

### S-01 — Paged customer grid

- **Covers:** FR-001, FR-002
- **Areas / files:** Pages/Customers.razor(.cs), Customers/CustomerQuery.cs, tests/CustomerQueryTests.cs
- **Prerequisites:** baseline captured
- **Verification:** `speckit-radzen gate G5 -Feature 001 -Slice S-01` and `speckit-radzen gate G6 -Feature 001`
- **Stop conditions:** Radzen member not found at compile time; service contract would need to change

### S-02 — Name search

- **Covers:** FR-003
- **Areas / files:** Pages/Customers.razor(.cs), tests/CustomerQueryTests.cs
- **Prerequisites:** S-01
- **Verification:** `speckit-radzen gate G5 -Feature 001 -Slice S-02` and `speckit-radzen gate G6 -Feature 001`
- **Stop conditions:** search semantics differ from the service's contains behaviour

## Risks

| Risk | Mitigation |
|---|---|
| FirstPage signature differs in the installed Radzen version | G5 build; fallback to Reload() recorded as new evidence |

## Explicit non-goals

- Authentication, sorting, editing, export.
