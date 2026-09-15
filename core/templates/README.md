# Templates

`speckit-radzen new-feature` copies these templates into `specs/NNN-name/`. Placeholders use `{{double braces}}`; the artifact linter fails while any placeholder remains. HTML comments (`<!-- … -->`) are guidance and may be deleted.

| Template | Phase | Lint rules |
|---|---|---|
| `discovery.md` | 01 discover | required sections, scope classification, no blocking unknowns at G1 |
| `spec.md` | 02 specify / 03 clarify | IDs, FR→AC coverage, authorization matrix, data volume, UI states, no `[NEEDS CLARIFICATION]` at G2 |
| `gap-analysis.md` | 02 specify | required sections |
| `clarifications.md` | 03 clarify | every Q has a decision |
| `plan.md` | 04 plan | constitution check P-01…P-16, layer impact without `unknown`, MCP references, slices with verification |
| `test-scenarios.md` | 04 plan | every AC mapped |
| `tasks.md` | 05 tasks | task IDs, slice and FR references |
| `review.md` | 08 review / 09 done | checklists answered |
| `adr.md` | any | — |

Generated (no template): `state.json`, `mcp-evidence.json` / `.md`, `analysis.md`, `gates/*.json`, `gate-report.md`.

Section headings are part of the lint contract (`lint-rules.json`). Rename them only together with the rules.
