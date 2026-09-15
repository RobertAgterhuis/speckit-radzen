# Implementation Plan: {{feature title}}

- **Feature:** {{NNN-name}}
- **Spec:** `spec.md` · **Evidence:** `mcp-evidence.md` · **Tests:** `test-scenarios.md`

## Context

{{Two to five sentences: what is built and where.}}

## Relevant repository evidence

- {{file:line — what it proves}}

## Constitution check

<!-- Status: complies / n/a / deviation. A deviation needs a justification and an approver. -->

| Principle | Status | Notes |
|---|---|---|
| P-01 Repository Awareness | {{…}} | {{…}} |
| P-02 Architecture Preservation | {{…}} | {{…}} |
| P-03 Radzen MCP First | {{…}} | {{…}} |
| P-04 Version Awareness | {{…}} | {{…}} |
| P-05 Requirement-Driven Component Selection | {{…}} | {{…}} |
| P-06 Separation of Concerns | {{…}} | {{…}} |
| P-07 Security Boundary | {{…}} | {{…}} |
| P-08 Explicit UI States | {{…}} | {{…}} |
| P-09 Responsive and Accessible Baseline | {{…}} | {{…}} |
| P-10 Data-Volume Awareness | {{…}} | {{…}} |
| P-11 Small Vertical Slices | {{…}} | {{…}} |
| P-12 Verification | {{…}} | {{…}} |
| P-13 Stop Conditions | {{…}} | {{…}} |
| P-14 Evidence Over Assumption | {{…}} | {{…}} |
| P-15 Recorded MCP Evidence | {{…}} | {{…}} |
| P-16 Render-Mode Correctness | {{…}} | {{…}} |

## Layer impact

<!-- no change / modify / add. "unknown" fails G3. -->

| Layer | Impact | Areas / files |
|---|---|---|
| UI | {{…}} | {{…}} |
| Shared UI | {{…}} | {{…}} |
| Contracts | {{…}} | {{…}} |
| Application / services | {{…}} | {{…}} |
| API / endpoints | {{…}} | {{…}} |
| Middleware | {{…}} | {{…}} |
| Authorization | {{…}} | {{…}} |
| Persistence | {{…}} | {{…}} |
| Tests | {{…}} | {{…}} |
| Configuration | {{…}} | {{…}} |

## Approved dependency changes

<!-- New packages, projects or framework references. Write "None." if there are none. Anything not listed fails G7. -->

- None.

## Component strategy

| UI element | Component | Reuse level | Reason | Evidence |
|---|---|---|---|---|
| {{Customer list}} | {{RadzenDataGrid / AppGrid wrapper}} | {{existing wrapper / Radzen / composition / custom}} | {{…}} | {{MCP-001}} |

## Radzen MCP verification

<!-- Every Radzen component, member or service relied on. Each row references an MCP-### entry (speckit-radzen evidence add). -->

| Component / service | Members | Evidence |
|---|---|---|
| {{RadzenDataGrid}} | {{LoadData, Count, IsLoading}} | {{MCP-001}} |

## Render mode

| Page / component | Render mode | Prerendering | Handling |
|---|---|---|---|
| {{Pages/Customers.razor}} | {{InteractiveServer (inherited from Routes)}} | {{on/off}} | {{…}} |

## Security model

| Actor | Operation | Enforcement point | Data exposed | Forbidden behaviour |
|---|---|---|---|---|
| {{…}} | {{…}} | {{…}} | {{…}} | {{…}} |

## Data flow

{{Request/response shapes, where paging/filtering/sorting happen, cancellation, caching.}}

## UI states

{{How each state from the spec's UI-state matrix is implemented, following the analogous feature.}}

## Responsive and accessibility strategy

{{Breakpoints, column priority, dialog widths, keyboard, focus, labels.}}

## Testing strategy

{{Levels and frameworks from the detected test stack. See test-scenarios.md.}}

## Vertical slices

### S-01 — {{objective}}

- **Covers:** {{FR-001, AC-001}}
- **Areas / files:** {{…}}
- **Prerequisites:** {{…}}
- **Verification:** `speckit-radzen gate G5 -Feature {{NNN}} -Slice S-01` and `speckit-radzen gate G6 -Feature {{NNN}}`
- **Stop conditions:** {{…}}

## Risks

| Risk | Mitigation |
|---|---|
| {{…}} | {{…}} |

## Explicit non-goals

- {{…}}
