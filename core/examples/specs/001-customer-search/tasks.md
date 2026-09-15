# Tasks: Customer search

## S-01 — Paged customer grid

- [x] **T-001** — Add `CustomerQuery` mapping from LoadDataArgs
  - **Slice:** S-01
  - **Covers:** FR-001, FR-002, AC-001
  - **Files / areas:** src/Sample.Web/Customers/CustomerQuery.cs
  - **Prerequisites:** none
  - **Constraints:** no new packages
  - **MCP evidence:** MCP-003
  - **Implementation:** record `CustomerQuery(Skip, Take, Name)` with `From(LoadDataArgs, string?)`, default page size 20
  - **Verification:** CustomerQueryTests
  - **Done when:** tests pass
  - **Stop if:** LoadDataArgs members differ from evidence
- [x] **T-002** — Add the Customers page with a server-paged grid
  - **Slice:** S-01
  - **Covers:** FR-001, FR-002, AC-002
  - **Files / areas:** src/Sample.Web/Components/Pages/Customers.razor, Customers.razor.cs
  - **Prerequisites:** T-001
  - **Constraints:** inherit global render mode; follow Home.razor conventions
  - **MCP evidence:** MCP-001
  - **Implementation:** RadzenDataGrid with LoadData, Count, IsLoading, AllowPaging, PageSize 20, EmptyText
  - **Verification:** `speckit-radzen gate G5 -Feature 001 -Slice S-01`
  - **Done when:** build and tests pass; G6 clean
  - **Stop if:** compile error on a Radzen member
- [x] **T-003** [P] — Unit tests for paging
  - **Slice:** S-01
  - **Covers:** AC-001, AC-002
  - **Files / areas:** tests/Sample.Web.Tests/CustomerQueryTests.cs
  - **Prerequisites:** T-001
  - **Constraints:** xUnit, as existing tests
  - **MCP evidence:** none needed
  - **Implementation:** TS-001, TS-002
  - **Verification:** `dotnet test`
  - **Done when:** tests pass
  - **Stop if:** —

## S-02 — Name search

- [x] **T-004** — Add the name search box
  - **Slice:** S-02
  - **Covers:** FR-003, AC-003, AC-004
  - **Files / areas:** src/Sample.Web/Components/Pages/Customers.razor, Customers.razor.cs
  - **Prerequisites:** S-01
  - **Constraints:** search on Change (Q-002)
  - **MCP evidence:** MCP-002, MCP-001
  - **Implementation:** RadzenFormField + RadzenTextBox Change → set filter, `grid.FirstPage(true)`
  - **Verification:** `speckit-radzen gate G5 -Feature 001 -Slice S-02`
  - **Done when:** build, tests, G6 clean
  - **Stop if:** FirstPage not available (see plan risk)
- [x] **T-005** [P] — Unit test for the name filter
  - **Slice:** S-02
  - **Covers:** AC-003
  - **Files / areas:** tests/Sample.Web.Tests/CustomerQueryTests.cs
  - **Prerequisites:** T-001
  - **Constraints:** xUnit
  - **MCP evidence:** none needed
  - **Implementation:** TS-003
  - **Verification:** `dotnet test`
  - **Done when:** test passes
  - **Stop if:** —
