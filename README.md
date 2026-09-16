# Spec Kit Radzen 2

Repository-aware, **MCP-first** spec-driven development for **Radzen Blazor** features with AI coding agents (Claude Code, GitHub Copilot, Codex, Cursor and any agent that reads Markdown).

Spec Kit Radzen gives an agent a strict way of working in *your* repository:

- **Automatic project detection** — SDK, hosting model, render modes, Radzen version and wiring, architecture, security and test stack, each fact with evidence and confidence.
- **MCP-first workflow** — every Radzen API the agent uses is checked with the Radzen Blazor MCP and recorded as `MCP-###` evidence; the compiler has the final word.
- **Quality gates G0–G8** — executable pass/fail checks between phases: artifact lint, traceability, build + new warnings + tests, anti-pattern scan, dependency drift, done.
- **68 anti-patterns** — Radzen usage, render modes, security, forms, data volume, accessibility, responsive design, architecture, testing and agent behaviour; most are detected automatically.
- **Templates with traceability IDs** — `specs/NNN-feature/` with FR → AC → test scenario → task → slice.
- **Generated agent adapters** — one canonical operating contract rendered for every agent.
- **Safe lifecycle** — atomic install, update that keeps your edits, clean uninstall, V1 migration.

## Requirements

- PowerShell **7.4+** (`pwsh`) on Windows, macOS or Linux
- .NET SDK of the target repository (for gate G5)
- Radzen Blazor MCP access (trial, Pro or Team licence) — see [docs/mcp-setup.md](docs/mcp-setup.md)

## Quick start

```powershell
# 1. Install into your repository (adapters are auto-detected; confirm or pass -Agents)
./install/Install-SpecKitRadzen.ps1 -Repository G:\Repos\MyApp -McpClient ClaudeCode,VSCode

# 2. Give the MCP its key (never in a file in the repository)
[Environment]::SetEnvironmentVariable('RADZEN_MCP_KEY', '<your key>', 'User')

# 3. In the repository
cd G:\Repos\MyApp
pwsh .speckit/radzen/tools/speckit-radzen.ps1 detect
pwsh .speckit/radzen/tools/speckit-radzen.ps1 mcp-check -Probe
pwsh .speckit/radzen/tools/speckit-radzen.ps1 baseline
```

macOS/Linux: `./install/install.sh /path/to/repo --agents claude,copilot --mcp-client ClaudeCode --yes`.

Then ask your agent, for example in Claude Code: `/speckit-radzen.bootstrap Add a customer overview with paging and search`. The agent walks the phases, runs the gates and reports their results.

## How it works

```text
00 bootstrap ─G0─▶ 01 discover ─G1─▶ 02 specify ─▶ 03 clarify ─G2─▶ 04 plan ─G3─▶ 05 tasks ─▶ 06 analyze ─G4─▶
   per slice: 07 implement ─G5 (build/test)─G6 (anti-pattern scan)─▶ 08 review ─G7─▶ 09 done ─G8─▶
```

| You get in the repository | Purpose |
|---|---|
| `.speckit/radzen/core/` | Constitution, workflows, gates, MCP rules, standards, patterns, templates, anti-patterns |
| `.speckit/radzen/tools/` | PowerShell module + `speckit-radzen.ps1` CLI |
| `.speckit/radzen/profile.md` | Detected project profile |
| `.speckit/radzen/local/` | Your amendments (never overwritten) |
| `specs/NNN-name/` | Spec, plan, tasks, MCP evidence, gate results per feature |
| Agent adapters | `.claude/`, `.github/`, `.agents/`, `.cursor/`, `SPECKIT-RADZEN.md` + managed blocks in `CLAUDE.md`, `AGENTS.md`, `copilot-instructions.md` |

## CLI

```text
pwsh .speckit/radzen/tools/speckit-radzen.ps1 help
```

`status`, `detect`, `verify-install`, `mcp-check`, `baseline`, `new-feature`, `state`, `phase`, `lint`, `analyze`, `evidence add|list`, `scan`, `gate G0..G8`, `install`, `update`, `uninstall`. Every command accepts `-Json`. Exit codes: 0 pass · 1 fail · 2 pass with waivers · 3 cannot evaluate.

## Documentation

| Document | For |
|---|---|
| [docs/user-guide.md](docs/user-guide.md) | Installing, daily use, the phases and gates, updating |
| [docs/mcp-setup.md](docs/mcp-setup.md) | Radzen MCP per client, keys, troubleshooting |
| [docs/authoring-guide.md](docs/authoring-guide.md) | Extending the kit: rules, detection, patterns, adapters |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Common problems |
| [core/README.md](core/README.md) | The canonical rule set |
| [core/examples/specs/001-customer-search](core/examples/specs/001-customer-search/spec.md) | A complete worked feature |
| [docs/adr/](docs/adr/README.md) | Architecture decisions |
| [docs/plan/](docs/plan/speckit-radzen-v2-implementation-plan.md) | The V2 implementation plan |

## Developing the kit

```powershell
./build/Build-Adapters.ps1      # regenerate integrations/ from core/agents/
./build/Build-Catalog.ps1       # regenerate core/antipatterns/*.md from rules.json
./build/Test-Drift.ps1          # generated files up to date?
./build/Test-Repository.ps1     # schemas, links, secrets, versions
./build/Invoke-Tests.ps1        # Pester (add -CI for results + coverage, -IncludeBuild for the NuGet e2e test)
./build/Build-Package.ps1       # dist/speckit-radzen-<version>.zip + checksum
```

CI workflows live in `build/ci/` — copy them to `.github/workflows/` to activate.

## Licence

MIT — see [LICENSE](LICENSE).
