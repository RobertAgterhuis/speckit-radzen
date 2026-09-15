# Spec Kit Radzen V1

Generic, repository-aware Spec Kit for building Radzen Blazor application features with AI agents and Radzen MCP.

## Design goals
- Generic: no project, cloud, database, architecture, .NET version, or hosting model is assumed.
- Repository-aware: inspect frontend, backend, middleware, contracts, security, persistence, tests, and shared code relevant to the feature.
- Architecture-preserving: existing repository conventions win over agent preference.
- Radzen MCP-first: verify current Radzen component APIs instead of inventing them.
- Version-aware: detect installed SDKs, target frameworks, packages, and Radzen version.
- Security-aware: UI visibility is never treated as authorization enforcement.
- Small slices: plan and implement the smallest coherent vertical changes.
- Verifiable: build, tests, security, responsive/accessibility, and UI states are explicit gates.

## Workflow
1. Read `constitution/constitution.md`.
2. Run repository discovery.
3. Create a project profile.
4. Specify observable feature behavior.
5. Perform capability/gap analysis.
6. Clarify only material ambiguities.
7. Create an implementation plan.
8. Verify Radzen APIs through MCP where required.
9. Create small tasks.
10. Implement one slice at a time.
11. Build/test/review each slice.
12. Apply Definition of Done.

## V1 non-goals
V1 does not mandate Clean Architecture, CQRS, MediatR, FluentValidation, MAUI, Azure, a database, a test framework, a design system, or a particular Radzen/.NET version.
