# Capability / Gap Analysis: Customer search

| Capability | Required | Exists | Evidence | Gap | Proposed layer |
|---|---|---|---|---|---|
| Read | yes | yes | Customers/ICustomerService.cs | none | — |
| Create | no | no | — | none | — |
| Update | no | no | — | none | — |
| Delete | no | no | — | none | — |
| Paging / filtering / sorting | paging + name filter | yes (service) | Customers/InMemoryCustomerService.cs | UI binding | UI |
| Validation | no | — | — | none | — |
| Authorization | no (non-goal) | no | Program.cs | accepted | — |
| Contract / DTO | yes | yes | Customers/CustomerSummary.cs | none | — |
| Endpoint / service | yes | yes | Program.cs (DI registration) | none | — |
| Error mapping | default | yes | Blazor default error UI | none | — |
| Radzen wiring (services, host, theme, render mode) | yes | yes | Program.cs, MainLayout.razor, App.razor | none | — |
| UI | yes | no | — | Customers page | UI |
| Tests | yes | partial | tests/Sample.Web.Tests | query mapping tests | Tests |

## Architecture impact

| Layer | Impact | Notes |
|---|---|---|
| UI | add | Pages/Customers.razor (+ code-behind) |
| Shared UI | no change | — |
| Contracts | no change | — |
| Services | no change | — |
| Endpoints | no change | — |
| Middleware | no change | — |
| Authorization | no change | non-goal |
| Persistence | no change | — |
| Tests | add | CustomerQueryTests |
| Configuration | no change | — |

## Material unknowns

- None.

## Out-of-scope findings

- No authentication in the sample app.
