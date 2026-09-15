# Testing

Discover and use the repository's test stack (`testing.*` in the profile). Do not add a framework because it is common (P-02).

## Choose the boundary that matches the change

| Change | Test at |
|---|---|
| Query/mapping/business logic | unit tests |
| Component behaviour (states, callbacks, rendering of data) | component tests (bUnit) when the repository has them |
| Endpoint, authorization, validation | integration tests (`WebApplicationFactory`) when present |
| Critical user journeys | E2E (Playwright) when present |

## Radzen specifics

- Keep logic that is easy to test out of the component (for example mapping `LoadDataArgs` to a query) and unit test it.
- bUnit + Radzen: register the Radzen services in the test context and use the repository's JS interop setup (Radzen components call JS). Verify the setup against an existing component test before writing a new one.
- Prefer behaviour assertions over full-markup snapshots (AP-TST-02).
- Never skip, delete or weaken tests to pass a gate (AP-TST-01/03).

## Traceability

Every AC maps to at least one `TS-###` in `test-scenarios.md`; automated scenarios name the test.
