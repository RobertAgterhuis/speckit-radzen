# User Guide

## 1. Install

Requirements: PowerShell 7.4+, the target repository's .NET SDK, git (recommended).

```powershell
# from the Spec Kit Radzen distribution folder
./install/Install-SpecKitRadzen.ps1 -Repository <repo>                      # auto-detect agents, asks to confirm
./install/Install-SpecKitRadzen.ps1 -Repository <repo> -Agents claude,copilot -McpClient ClaudeCode,VSCode -Yes
./install/Install-SpecKitRadzen.ps1 -Repository <repo> -Agents claude -EnableHooks   # scan after every edit (Claude Code)
./install/Install-SpecKitRadzen.ps1 -Repository <repo> -WhatIf                        # show what would change
```

| Option | Meaning |
|---|---|
| `-Agents` | `claude`, `copilot`, `codex`, `cursor`, `generic`, `all`. Default: detected from `CLAUDE.md`/`.claude`, `.github/copilot-instructions.md`/`.github/instructions`, `.github/prompts`, `.github/agents`/`.vscode/mcp.json`, `AGENTS.md`/`.codex`, `.cursor`; otherwise `generic`. |
| `-McpClient` | Adds the `radzen-blazor` server (without a key) to `.mcp.json`, `.vscode/mcp.json`, `.vs/mcp.json`, `.cursor/mcp.json` or `.codex/config.toml`. Existing entries are never replaced. |
| `-EnableHooks` | Claude Code PostToolUse hook that runs `scan` after edits. |
| `-Force` | Overwrite existing unmanaged or locally modified files (they are backed up in `.speckit/radzen/backup/`). |

What the installer never does: delete your files, overwrite your instruction files (it merges a marked block), write licence keys, change application code or packages.

Commit the result (`.speckit/radzen/`, adapters, managed blocks). `.gitignore` gets a managed block for temporary kit files.

## 2. First run in a repository

```powershell
$sk = 'pwsh .speckit/radzen/tools/speckit-radzen.ps1'   # or define an alias/function
pwsh .speckit/radzen/tools/speckit-radzen.ps1 detect      # writes .speckit/radzen/profile.md
pwsh .speckit/radzen/tools/speckit-radzen.ps1 mcp-check -Probe
pwsh .speckit/radzen/tools/speckit-radzen.ps1 baseline    # before the first change
```

Read `profile.md`. Fix or accept the **Health** items. A blocker (for example Radzen not registered) must be fixed in an approved slice or allowed in `.speckit/radzen/config.json` → `gates.G0.allowHealth`.

Multiple solutions? `detect -Solution path/to/App.sln` (remembered in `config.json`).

## 3. Building a feature with an agent

Start the agent in the repository and ask for the feature through the bootstrap command/prompt:

| Agent | Start with |
|---|---|
| Claude Code | `/speckit-radzen.bootstrap <request>` (then `/speckit-radzen.discover`, …) — or just describe the feature; the `speckit-radzen` skill triggers on Radzen work |
| GitHub Copilot (VS Code) | `/speckit-radzen.bootstrap` prompt file in agent mode; `@speckit-radzen-reviewer` custom agent for review |
| Codex | "Use the speckit-radzen skill to …" (AGENTS.md points to it) |
| Cursor | `/speckit-radzen-bootstrap` command; rules apply automatically |
| Other | "Follow SPECKIT-RADZEN.md to …" |

The agent then works phase by phase. Your role:

- **Clarify (phase 03):** answer the material questions (authorization, delete semantics, data volume, scope).
- **Plan (phase 04):** approve dependency changes and deviations from the constitution.
- **Review (phase 08):** read `review.md`, check the waivers.
- **Done (phase 09):** read `gate-report.md`.

Useful commands while the agent works:

```text
state                     # phase, gates, next step
gate G5 -Feature 001 -Slice S-01
scan -Feature 001
lint -Feature 001
evidence list -Feature 001
```

### Small changes

For a trivial change (a label, a typo) agree with the agent to skip phases 02–06 (`phase … -Force -Note "trivial change agreed"`). G5 and G6 still run.

## 4. Gates

| Gate | When | Blocks on |
|---|---|---|
| G0 | bootstrap | stale profile, blocker health, ambiguous solution, unrecorded MCP availability, secret in MCP config |
| G1 | discover | missing trace/scope, blocking unknowns |
| G2 | clarify | FR without AC, open clarifications, missing authorization/data volume/UI states |
| G3 | plan | constitution check, unknown layer impact, Radzen APIs without evidence, slices without verification |
| G4 | analyze | traceability errors, missing/weak evidence |
| G5 | each slice | build errors, new warnings, new test failures |
| G6 | each slice | blocker/major anti-patterns in changed files |
| G7 | review | unverified slices, unanswered checklist items, open findings, unapproved dependency changes |
| G8 | done | any gate not passed, code changed after gates, open tasks |

Details: `.speckit/radzen/core/gates/quality-gates.md`.

### Waivers

A finding that is acceptable in context:

```razor
@* speckit-radzen:ignore AP-RDZ-02 reason="status list, max 6 rows (Q-003)" *@
<RadzenDataGrid Data="@statuses" ... />
```

Repository-wide: `.speckit/radzen/config.json` → `scan.waivers: [{ "rule": "AP-ARC-05", "path": "src/Legacy/**", "reason": "legacy module, tracked in #412" }]`.

## 5. Configuration

`.speckit/radzen/config.json` (all optional):

```json
{
  "solution": "src/App.sln",
  "specsDirectory": "specs",
  "scan": { "excludePaths": ["**/Generated/**"], "disabledRules": [], "severityOverrides": { "AP-RSP-01": "major" }, "waivers": [] },
  "gates": {
    "G0": { "allowHealth": [] },
    "G4": { "maxEvidenceRank": 3 },
    "G5": { "enabled": true, "allowNewWarnings": 0, "testFilter": "Category!=E2E", "buildConfiguration": "Debug", "timeoutMinutes": 20, "runTests": true },
    "G6": { "failOn": ["blocker", "major"] }
  }
}
```

Local amendments go in `.speckit/radzen/local/` (see its README).

## 6. CI

Copy `.speckit/radzen/core/ci/speckit-radzen-gates.yml` to `.github/workflows/`. On pull requests from `feature/NNN-*` branches it verifies the install, re-detects, runs G6 and G5, runs G8 when the feature is in review/done, and uploads the gate results (including SARIF).

## 7. Update, verify, uninstall

```powershell
# from the NEW distribution folder
./install/Install-SpecKitRadzen.ps1 -Repository <repo> -Update
./install/Install-SpecKitRadzen.ps1 -Repository <repo> -Verify
./install/Install-SpecKitRadzen.ps1 -Repository <repo> -Uninstall
```

- Unmodified managed files are replaced; files you changed are kept and the new version is written as `<file>.speckit-new` — merge it and delete the `.speckit-new` file (`verify-install` reports unmerged updates).
- `.speckit/radzen/local/`, `config.json` and `specs/` are never touched.
- V1 installs are migrated by `-Update` (or `-Force` when V1 adapter files exist); the old files are backed up.

Uninstall removes managed files, blocks, MCP entries and hooks it added; modified files are kept and listed.
