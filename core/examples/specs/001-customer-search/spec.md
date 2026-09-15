# Feature Specification: Customer search

- **Feature:** 001-customer-search
- **Status:** Approved
- **Discovery:** `discovery.md`

## Problem

Sales staff cannot see the customer list in the application. They need to browse customers and find one by name quickly.

## Actors

| Actor | Description | Authentication context |
|---|---|---|
| Sales user | Internal user who looks up customers | Anonymous in the sample app (see non-goals) |

## User stories

- **US-001 (P1)** — As a sales user, I want to page through customers so that I can browse the list without long load times.
- **US-002 (P1)** — As a sales user, I want to search customers by name so that I can find a customer quickly.

## Functional requirements

- **FR-001** — The system shows customers (name, city) on a `/customers` page, 20 per page, loaded page by page from the server. (US-001)
- **FR-002** — The system shows the total number of customers and lets the sales user move between pages. (US-001)
- **FR-003** — The sales user can filter the list by a name fragment (case-insensitive); the list restarts at the first page. (US-002)

## Acceptance criteria

- **AC-001** (FR-001) — **Given** 250 customers exist, **when** the sales user opens `/customers`, **then** 20 customers are shown and only 20 are requested from the service.
- **AC-002** (FR-002) — **Given** the first page is shown, **when** the sales user goes to page 2, **then** customers 21–40 are shown and the pager reports 250 items.
- **AC-003** (FR-003) — **Given** the sales user is on page 3, **when** they search for "customer 00", **then** 9 matching customers are shown starting at page 1.
- **AC-004** (FR-003) — **Given** a search matches nothing, **when** the results load, **then** the grid shows "No customers found.".

## Authorization matrix

| Operation | Actor | Allowed | Enforcement point | Evidence / gap |
|---|---|---|---|---|
| Read customer list | Sales user | yes | none (sample app has no authentication) — accepted non-goal | src/Sample.Web/Program.cs |

## Data requirements

| Data | Source | Fields shown | Sensitive? |
|---|---|---|---|
| Customer | ICustomerService.GetPageAsync | Name, City | no |

## Data volume

- **Expected rows:** 250 → unknown growth
- **Bounded:** no
- **Paging / filtering / sorting boundary:** server, because the collection is unbounded and the service already pages and filters.

## UI states

| Screen / region | Initial | Loading | Success | Empty | Validation failure | Operational failure | Forbidden | Read-only | Stale / concurrency |
|---|---|---|---|---|---|---|---|---|---|
| Customers grid | first page requested on render | grid loading indicator (IsLoading) | rows + pager | "No customers found." | n/a – free-text search, no validation | default Blazor error UI (sample app convention) | n/a – no authorization in sample app | whole page is read-only | n/a – read-only, reload on navigation |

## Non-functional requirements

- **NFR-001** (responsive) — The page is usable at 375 px width: grid scrolls horizontally, search box spans the width.
- **NFR-002** (accessibility) — The search box has an accessible label; the grid is keyboard navigable.
- **NFR-003** (performance) — At most one service call per page change or search.

## Existing capabilities

- `ICustomerService.GetPageAsync(skip, take, nameContains)` returns a page and the total count (discovery trace).

## Gaps

- UI page only — see `gap-analysis.md`.

## Non-goals

- Authentication and authorization (the sample app has none).
- Editing customers, sorting, exporting.

## Constraints

- No new packages; use Radzen components already referenced.

## Assumptions

- Name filtering uses the service's existing case-insensitive contains semantics.

## Open questions

- None.
