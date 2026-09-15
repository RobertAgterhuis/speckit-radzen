# Spec Kit Radzen Core (v2)

The canonical, agent-neutral rule set for building Radzen Blazor features with AI agents. Agent adapters (Claude Code, GitHub Copilot, Codex, Cursor, generic) are generated from `agents/` and point back here.

## Design goals

- **Generic:** no project, cloud, database, architecture, .NET version or hosting model is assumed.
- **Repository-aware:** automatic project detection plus a feature-specific trace through frontend, backend, middleware, contracts, security, persistence and tests.
- **Architecture-preserving:** existing repository conventions win over agent preference.
- **MCP-first:** Radzen APIs are verified through the Radzen Blazor MCP and every decision is logged as evidence.
- **Version-aware:** SDK, target frameworks, render modes and the `Radzen.Blazor` version are detected, never assumed.
- **Security-aware:** UI visibility is never authorization.
- **Small slices, hard gates:** every slice is built, tested and scanned; the feature closes only with a gate report.

## Contents

| Folder | Purpose |
|---|---|
| `constitution/` | Principles P-01 … P-16 (normative) |
| `workflows/` | Phases 00–09 with entry/exit gates |
| `gates/` | Quality gates G0–G8: definitions and machine-readable `gates.json` |
| `mcp/` | MCP-first workflow, tool map, query playbook, fallback matrix, Studio guardrails |
| `discovery/` | Repository discovery, architecture detection, detection rules |
| `antipatterns/` | Anti-pattern catalog (AP-*) and scanner rules |
| `standards/` | Engineering standards, Radzen-specific |
| `patterns/` | UI patterns with spec questions, MCP recipes and pitfalls |
| `templates/` | Feature artifact templates and lint contract |
| `checklists/` | Review checklists, each item mapped to a gate |
| `agents/` | Canonical agent operating contract and role cards |
| `schemas/` | JSON Schemas for state, profile, evidence, gates, rules, config |
| `config/` | Default configuration |
| `examples/` | A complete worked feature |

## Quick flow

1. `speckit-radzen detect` → project profile
2. `speckit-radzen mcp-check` → MCP availability
3. `speckit-radzen new-feature "name"` → `specs/NNN-name/`
4. discover → specify → clarify → plan (with MCP evidence) → tasks → analyze
5. per slice: implement → `gate G5` → `gate G6`
6. review → `gate G7` → `gate G8`

`speckit-radzen` is shorthand for `pwsh .speckit/radzen/tools/speckit-radzen.ps1`.

## Traceability IDs

`US-###` user story · `FR-###` functional requirement · `NFR-###` non-functional requirement · `AC-###` acceptance criterion · `Q-###` clarification · `S-##` slice · `T-###` task · `TS-###` test scenario · `MCP-###` evidence · `AP-XXX-##` anti-pattern · `P-##` principle · `G#` gate. See ADR-0004.

## Non-goals

The core does not mandate Clean Architecture, CQRS, MediatR, FluentValidation, MAUI, Azure, a database, a test framework, a design system, or a particular Radzen/.NET version.

## Local amendments

Put repository-specific additions in `.speckit/radzen/local/` (never overwritten by upgrades):

- `constitution.local.md` — tightened or added principles (see constitution *Governance*).
- `antipatterns.local.json` — extra scanner rules in the same format as `antipatterns/rules.json`.
- `detection-rules.local.json` — extra detection rules.
- `standards/*.md` — house standards the agent should read alongside the core standards.
