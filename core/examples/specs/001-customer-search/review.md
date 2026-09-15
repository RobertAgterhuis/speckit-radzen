# Review: Customer search

- **Reviewer role:** reviewer (agents/roles/reviewer.md)
- **Commit / diff reviewed:** working tree after S-02

## Acceptance criteria

| AC | Satisfied | How / evidence |
|---|---|---|
| AC-001 | yes | Customers.razor.cs LoadData uses CustomerQuery (Take 20); TS-001 |
| AC-002 | yes | Count bound to total; TS-002 |
| AC-003 | yes | OnSearch → FirstPage(true); TS-003 |
| AC-004 | yes | EmptyText="No customers found."; TS-004 manual |

## Checklists

### Security

- [x] Sensitive operations have trusted-layer authorization — n/a – read-only sample without authentication (spec non-goal)
- [x] UI visibility is not relied on as enforcement — no hidden controls
- [x] Only necessary data is requested/rendered — name and city only
- [x] No secrets, tokens or internal exception details exposed — default error UI
- [x] Existing security middleware/controls preserved — Program.cs unchanged
- [x] Destructive behaviour explicitly understood — n/a – no destructive actions
- [x] Forbidden behaviour handled intentionally — n/a – no authorization

### UI states

- [x] Initial, loading, success, empty, failure states implemented as specified — IsLoading, EmptyText, default error UI
- [x] Forbidden / read-only handled — n/a – read-only page without authorization
- [x] Stale/concurrency considered — n/a – read-only

### Responsive and accessibility

- [x] Desktop, tablet, mobile reviewed — 1280/768/375 px checked
- [x] Keyboard and focus usable — Tab order search → grid → pager
- [x] Inputs/actions have accessible names — RadzenFormField label
- [x] Colour is not the only signal — no status colours

### Radzen usage

- [x] Every Radzen member has MCP evidence — MCP-001…MCP-003, compile-verified by G5
- [x] Render mode correct for changed pages — inherits InteractiveServer
- [x] Server-side paging for unbounded data — LoadData + Count
- [x] Dialog results null-checked — n/a – no dialogs

### Architecture

- [x] Follows the analogous feature and repository conventions — page conventions from Home.razor
- [x] No unapproved dependencies — G7 dependency-drift clean
- [x] No unrelated refactoring — diff limited to planned files

## Manual-review anti-patterns

| Rule | Result | Notes |
|---|---|---|
| AP-SEC-01 | ok | no UI-only authorization |
| AP-RND-02 | ok | no OnInitializedAsync data load |
| AP-A11Y-04 | ok | labelled via RadzenFormField |
| AP-RSP-02 | ok | single grid |

## Findings

| # | Severity | Finding | Status |
|---|---|---|---|
| 1 | minor | Sample app has no authentication (out of scope) | waived (non-goal, sales lead) |

## Definition of Done

- [x] Acceptance criteria are satisfied — table above
- [x] Repository architecture/conventions are preserved — G7
- [x] No unexplained scope creep — tasks only
- [x] Required Radzen APIs were verified — G4, G5
- [x] Build and relevant tests pass — G5
- [x] Anti-pattern scan clean — G6
- [x] Authorization enforced at the trusted boundary — n/a – non-goal
- [x] UI states considered — see UI states
- [x] Responsive and accessibility baseline reviewed — see above
- [x] No unresolved stop condition remains — none
