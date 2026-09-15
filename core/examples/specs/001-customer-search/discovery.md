# Discovery: Customer search

- **Feature:** 001-customer-search
- **Profile:** `.speckit/radzen/profile.md` (fingerprint recorded in `gates/G0.json`)
- **Solution:** BuildableSample.slnx

## Request

"Add a customer overview where sales staff can page through customers and search by name."

## Repository summary

| Aspect | Value | Confidence | Evidence |
|---|---|---|---|
| Hosting model / render mode of target area | Blazor Web App, global InteractiveServer | proven | src/Sample.Web/Components/App.razor:10 |
| Radzen version / wiring | Radzen.Blazor 7.x, AddRadzenComponents, RadzenComponents host, material theme | proven | src/Sample.Web/Program.cs:7, src/Sample.Web/Components/Layout/MainLayout.razor:2 |
| UI → backend interaction | In-process service interface `ICustomerService` (singleton) | proven | src/Sample.Web/Program.cs:8 |
| Authorization style | None configured (sample app) | proven | src/Sample.Web/Program.cs |
| Validation | None needed (read-only feature) | proven | — |
| Test stack for touched layers | xUnit + bUnit | proven | tests/Sample.Web.Tests/Sample.Web.Tests.csproj |

## Analogous feature

- `src/Sample.Web/Components/Pages/Home.razor` — only existing page; defines page conventions (Radzen typography, file-scoped `@page`). No existing grid; the Radzen MCP is the reference for grid usage.

## Feature dependency trace

```text
[Pages/Customers.razor] → [ICustomerService.GetPageAsync(skip, take, nameContains)] → [InMemoryCustomerService] → [in-memory list (250 rows)]
```

## Cross-cutting concerns

| Concern | Existing behaviour | Evidence |
|---|---|---|
| Error handling | Default Blazor error UI | src/Sample.Web/Program.cs |
| Logging / correlation | Default ASP.NET Core logging | src/Sample.Web/Program.cs |
| Localization | Not used | — |
| Caching / resilience | Not used | — |
| Concurrency | Read-only feature; not applicable | — |

## Scope classification

| Area | Classification | Notes |
|---|---|---|
| src/Sample.Web/Components/Pages | LIKELY CHANGE | new Customers page |
| src/Sample.Web/Customers | READ-ONLY CONTEXT | service already supports paging and name filter |
| src/Sample.Web/Program.cs | READ-ONLY CONTEXT | wiring already complete |
| tests/Sample.Web.Tests | LIKELY CHANGE | query mapping tests |
| authentication / authorization | OUT OF SCOPE | sample app has none; see non-goals |

## Unknowns

### Blocking

- None.

### Non-blocking

- Real data volume in production is unknown; the service is paged, so the UI stays server-paged regardless.

## Out-of-scope findings

- The sample app has no authentication. A production app would need a read policy for customer data.
