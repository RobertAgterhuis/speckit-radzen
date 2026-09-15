# Quality Gates

Gates turn the constitution into pass/fail checks. Run a gate with:

```text
speckit-radzen gate G# -Feature NNN [-Slice S-##]
```

Each run writes `specs/NNN-*/gates/G#.json` (schema `schemas/gate-result.schema.json`), updates `state.json`, and re-renders `gate-report.md`.

| Exit code | Meaning |
|---|---|
| 0 | pass |
| 1 | fail — fix and re-run |
| 2 | pass with waivers — review the waivers |
| 3 | cannot evaluate (missing input, tool unavailable) — **stop** (P-13.9) |

A gate is passed only when its result file says so. Agents report gate status by quoting the result, never from memory (AP-AGT-04).

## G0 — Context ready (phase 00)

| Check | Pass when |
|---|---|
| install-verified | `.speckit/radzen/install-manifest.json` matches the managed files (skipped when running from the distribution repository) |
| profile-present / profile-fresh | `profile.json` exists and its fingerprint matches the current project files |
| profile-health | no `blocker` health items, except those listed in `config.gates.G0.allowHealth` |
| solution-selected | the solution is unambiguous |
| mcp-availability-recorded | `state.json` → `mcp.availability` is not `unknown` |
| mcp-no-secret | `mcp-check` does not report `secret-in-repo` |
| dependency-snapshot | projects and package references are captured in `gates/dependencies.json` for G7 |

## G1 — Discovery complete (phase 01)

`discovery.md` lints clean in strict mode: required sections, dependency trace, valid scope classification, **no blocking unknowns**. Profile still fresh.

## G2 — Spec ready (phase 03)

`spec.md`, `gap-analysis.md` and `clarifications.md` lint clean in strict mode: every FR has an AC, ACs reference existing FRs, authorization matrix has enforcement points, data volume states bounded yes/no, UI-state matrix has no empty cells, **no `[NEEDS CLARIFICATION]`**, every Q has a decision.

## G3 — Plan ready (phase 04)

`plan.md` and `test-scenarios.md` lint clean in strict mode: constitution check covers P-01…P-16 with valid statuses (deviations justified), layer impact has no `unknown`, every slice covers FRs and has verification and stop conditions, every Radzen API row cites `MCP-###`, approved dependency changes stated, every AC has a test scenario.

## G4 — Consistent and MCP-verified (phase 06)

`tasks.md` lints clean; `speckit-radzen analyze` reports zero errors: FR→AC→TS→task→slice traceability, no orphans, every cited `MCP-###` exists, no unresolved conflicts, evidence rank ≤ `config.gates.G4.maxEvidenceRank` (default 3) or an approved rank-4 fallback.

## G5 — Slice build and test (phase 07, per slice)

| Check | Pass when |
|---|---|
| build | `dotnet build --no-incremental` of the selected solution succeeds |
| new-warnings | warnings not present in the baseline ≤ `config.gates.G5.allowNewWarnings` (default 0) |
| tests | `dotnet test` passes; failures that are recorded in the baseline are reported as pre-existing (waived) |
| evidence-compile-verified | evidence cited by the slice's tasks is marked compile-verified |

Requires a baseline (`speckit-radzen baseline`), captured before the first change.

## G6 — Anti-pattern scan (phase 07, per slice)

`speckit-radzen scan` on files changed since the feature's base commit: no active findings with a severity in `config.gates.G6.failOn` (default blocker, major). Writes `gates/scan.md` and `gates/scan.sarif`.

## G7 — Review (phase 08)

| Check | Pass when |
|---|---|
| slices-verified | every slice has passed G5 and G6 |
| review-lint | `review.md` lints clean in strict mode: every AC satisfied, every checklist item answered, no open blocker/major findings |
| dependency-drift | new/changed package references and new projects since G0 are listed under *Approved dependency changes* in `plan.md` |

The manual part — reading the diff against the checklists and manual-review anti-patterns — is the reviewer's job; `review.md` is its evidence.

## G8 — Done (phase 09)

| Check | Pass when |
|---|---|
| gates-passed | G0–G7 passed (or waived) |
| code-unchanged-since-gates | the code fingerprint equals the one recorded by the last G5, G6 and G7 runs |
| tasks-complete | every task in `tasks.md` is ticked |
| review-lint | as in G7 |
| report | `gate-report.md` rendered |

On pass, the feature phase becomes `done`.

## Configuration

`.speckit/radzen/config.json` (schema `schemas/config.schema.json`):

```json
{
  "gates": {
    "G0": { "allowHealth": ["RDZ-H04"] },
    "G4": { "maxEvidenceRank": 3 },
    "G5": { "enabled": true, "allowNewWarnings": 0, "testFilter": "Category!=E2E", "buildConfiguration": "Debug", "timeoutMinutes": 20, "runTests": true },
    "G6": { "failOn": ["blocker", "major"] }
  }
}
```

## CI

`core/ci/speckit-radzen-gates.yml` (GitHub Actions; installed at `.speckit/radzen/core/ci/`) runs G5, G6 and G8 for the feature named in the pull request branch (`feature/NNN-*`).
