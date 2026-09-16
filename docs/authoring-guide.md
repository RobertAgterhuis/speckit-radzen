# Authoring Guide

How to extend Spec Kit Radzen. Everything canonical lives in `core/`; generated files are rebuilt by scripts in `build/` and checked by CI.

## Layout

| Change | Edit | Then run |
|---|---|---|
| Agent instructions | `core/agents/*.md`, `core/agents/phases.json` | `build/Build-Adapters.ps1` |
| Anti-pattern rule | `core/antipatterns/rules.json` + fixture in `tests/fixtures/antipatterns/fixtures.json` | `build/Build-Catalog.ps1`, tests |
| Detection rule | `core/discovery/detection-rules.json` (+ fixture/test) | tests |
| Gate check | `tools/SpecKitRadzen/Public/Invoke-SkrQualityGate.ps1`, `core/gates/*` | tests |
| Template section | `core/templates/*.md` and `core/templates/lint-rules.json` (+ lint code) | tests |
| Pattern / standard | `core/patterns/*.md`, `core/standards/*.md` | `build/Test-Repository.ps1` (links) |
| MCP client | `mcp/templates/*`, `$script:SkrMcpClients` in `Private/Mcp.ps1` | tests |
| New agent | `build/Build-Adapters.ps1`, `$script:SkrAgents` and detection in `Private/Install.ps1` | tests |

Never edit `integrations/` or `core/antipatterns/*.md` by hand; `build/Test-Drift.ps1` fails.

## Adding an anti-pattern rule

1. Pick an ID in the right category (`AP-RDZ-15`), severity (`blocker` fails G6, `major` fails G6 unless waived, `minor` informs) and detection:
   - `regex` — `files` globs + `pattern`; optional `requires` (file must contain), `unless` (skip when the match or its line matches), `unlessInFile`, `excludeTests`.
   - `absence` — reported when a file matches `pattern` but not `requires`.
   - `tool` — implemented in code (scanner or gate).
   - `manual-review` — listed for G7 reviewers.
2. Fill `why`, `fix`, `principles`, `doc` (`<category>.md#<id lowercase>`), and `bad`/`good`/`mcpQuery` when useful.
3. Add a case to `tests/fixtures/antipatterns/fixtures.json` with at least one positive and one negative file. The negative file must contain the *legitimate* look-alike that the regex must not flag.
4. `./build/Build-Catalog.ps1; ./build/Invoke-Tests.ps1 -Path tests/unit/AntiPatterns.Tests.ps1`.

Precision first (ADR-0006): if you cannot write a negative fixture that passes, make the rule `manual-review`.

Repository-specific rules belong in the target repository's `.speckit/radzen/local/antipatterns.local.json` (same schema).

## Adding a detection rule

```json
{ "id": "arch.messaging.masstransit", "fact": "architecture.messaging", "value": "MassTransit", "kind": "package", "pattern": "^MassTransit", "confidence": "proven", "multi": true }
```

`kind`: `package` (package id regex), `content` (regex in `files`, default `*.cs`/`*.razor`; test projects are ignored except for `testing.*` facts), `file` (file name regex). Add an assertion to `tests/unit/Detection.Tests.ps1` using a fixture repository.

## Adding a fixture repository

Minimal files only: solution, project files, `Program.cs`, `App.razor`, layouts, a page or two. Add a `global.json` when the fixture has no solution at its root (the repository root is resolved by `.git`, `.speckit/radzen`, a solution file or `global.json`).

## Scenarios

Add `tests/scenarios/SC-NN.md` with sections *Prompt*, *Must*, *Must not*, *Scoring* and a *Harness* JSON block (`fixture`, `agents`, `setup`, `checks`). Supported check types are implemented in `Invoke-Scenario.ps1`.

## Releasing

1. Update `VERSION`, `core/VERSION`, `manifest.json`, `tools/SpecKitRadzen/SpecKitRadzen.psd1` and `CHANGELOG.md`.
2. `./build/Build-Adapters.ps1; ./build/Build-Catalog.ps1` (the version is stamped into generated files).
3. `./build/Test-Drift.ps1; ./build/Test-Repository.ps1; ./build/Invoke-Tests.ps1 -CI -IncludeBuild`.
4. Run at least SC-01 … SC-06 with the agents you support and commit the results.
5. Tag `vX.Y.Z`; the release workflow builds `dist/` and publishes it.
