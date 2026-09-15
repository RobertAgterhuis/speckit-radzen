# Example — Generic Customer Search

This example demonstrates the reasoning shape, not a mandated architecture.

## Requirement
Add a customer search screen with filtering and paging.

## Discovery result
Assume the repository reveals:
- existing CustomerSummary contract
- existing paged customer query endpoint
- existing authorized customer-read policy
- existing UI service/client
- Radzen already installed
- existing component tests

## Gap
Backend: no change.
Contracts: no change.
Authorization: no change.
UI: add search page.
Tests: add component behavior coverage.

## Plan
1. Verify the current Radzen data-grid/load APIs through MCP.
2. Implement the page using the repository's existing client and layout conventions.
3. Keep filtering/paging server-side.
4. Implement loading, empty, failure, and forbidden behavior consistent with the repository.
5. Review constrained-width grid behavior.
6. Add tests using the existing test stack.
7. Build and run relevant tests.

If discovery instead showed no paging endpoint, the plan would surface a backend capability gap rather than silently loading every customer into the browser.
