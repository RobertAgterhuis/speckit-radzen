# ADR-0004: Feature artifact layout and traceability IDs

- **Status:** Accepted (2026-09-15)

## Decision

Each feature lives in `specs/NNN-kebab-name/`:

| File | Produced by | Purpose |
|---|---|---|
| `state.json` | all phases | Current phase, passed gates, timestamps |
| `spec.md` | specify | Observable behaviour, FR/NFR/AC |
| `gap-analysis.md` | specify | Capability vs evidence |
| `clarifications.md` | clarify | Q-### decisions |
| `plan.md` | plan | Constitution check, layer impact, slices |
| `tasks.md` | tasks | T-### tasks |
| `mcp-evidence.json` / `.md` | plan, implement | MCP-### evidence |
| `test-scenarios.md` | plan/tasks | AC → test mapping |
| `analysis.md` | analyze | Traceability matrix |
| `review.md` | review | Review report |
| `gates/G#.json`, `gate-report.md` | gate runner | Gate results |

ID scheme (numbers are zero-padded to three digits, unique within the feature):

| Prefix | Meaning |
|---|---|
| `US-###` | User story |
| `FR-###` | Functional requirement |
| `NFR-###` | Non-functional requirement |
| `AC-###` | Acceptance criterion |
| `Q-###` | Clarification question |
| `S-##` | Vertical slice |
| `T-###` | Task |
| `TS-###` | Test scenario |
| `MCP-###` | MCP evidence entry |
| `AP-XXX-##` | Anti-pattern (global catalog) |
| `P-##` | Constitution principle (global) |
| `G#` | Quality gate (global, G0–G8) |

Project-level artifacts live in `.speckit/radzen/` (`profile.json`, `profile.md`, `config.json`, `baseline/`).

## Consequences

The artifact linter and the `analyze` phase can check coverage mechanically (every FR has an AC, every FR is covered by a task, every task maps to a slice).
