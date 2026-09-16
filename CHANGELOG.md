# Changelog

## 2.0.0 — 2026-09-16

Production-grade rewrite on top of V1 (see `docs/plan/speckit-radzen-v2-implementation-plan.md`).

### Added

- **Automatic project detection** (`detect`): machine-readable `profile.json` + `profile.md` with evidence and confidence; hosting model, render modes, prerendering, Radzen version/registration/theme/script/host/wrappers, architecture, security and test stack; 84 declarative detection rules; health checks (RDZ-H01…H07, RND-H01/H02, REPO-H01/H02); freshness fingerprint; multi-solution handling.
- **MCP-first workflow**: tool map for Radzen Blazor MCP (`search`, `X-Radzen-Key`) and Radzen Blazor Studio MCP, query playbook, fallback matrix, Studio guardrails, evidence log (`evidence add`, `mcp-evidence.json/.md`) with source ranks, compile verification by G5, per-client config templates (Claude Code, VS Code, Visual Studio, Cursor, Codex) without secrets, `mcp-check` with optional endpoint probe.
- **Quality gates G0–G8** (`gate`): executable checks, JSON results, `gate-report.md`, exit codes, build warning/test baseline (`baseline`), dependency drift, code fingerprint re-validation, CI template.
- **Anti-pattern catalog**: 68 rules in 11 categories with fixes and MCP queries; scanner with inline/file/config waivers, SARIF + Markdown output, local rules, severity overrides.
- **Constitution v2**: principles P-01…P-16 linked to gates; governance and local amendments.
- **Workflows 00–09** with entry/exit gates; new bootstrap, analyze and done phases; phase state machine (`phase`, `state`).
- **Templates** with traceability IDs and a lint contract (`lint`), cross-artifact analysis (`analyze`).
- **Standards** (13) and **patterns** (15) with Radzen-specific guidance.
- **Agent adapters generated** from `core/agents/` for Claude Code (skill, 13 commands, 2 sub-agents, optional hook), GitHub Copilot (skill, path instructions, prompt files, reviewer agent), Codex, Cursor (rules, commands) and generic agents; role cards.
- **Installer v2**: atomic install with rollback, hash manifest, managed blocks in shared instruction files, update that keeps local edits (`*.speckit-new`), uninstall, verify, V1 migration, MCP and hook merging, dry-run.
- **Tests**: 240 Pester tests (unit + integration), 10 fixture repositories, 39 scanner fixture pairs, NuGet end-to-end test on a buildable Radzen sample, 20 agent-behaviour scenarios with harness and rubric; CI for Windows, Linux and macOS.
- Worked example `core/examples/specs/001-customer-search` with implementation overlay.
- ADRs 0001–0006, user guide, MCP setup guide, authoring guide, troubleshooting.

### Changed

- V1 workflow, template and checklist files were renamed/replaced (`build/obsolete-files.json`; run `build/Remove-ObsoleteFiles.ps1` in existing clones).
- Adapter folders in the distribution are stored as `dot-<name>` and mapped by the installer.
- `install.sh` is a POSIX wrapper around the PowerShell installer (bash 3.2 compatible).

### Fixed (V1 defects)

- Codex/Generic adapter collision; wrong Copilot auto-detection on any `.github` folder; existing `AGENTS.md`/`copilot-instructions.md` never receiving instructions; `-Force` wiping local changes; non-atomic install; bash 4-only syntax; version drift.

## 1.1.0

- Portable distribution with Claude Code, Codex, Copilot and generic adapters, PowerShell/Bash installers and an MCP policy.

## 1.0.0

- Initial generic repository-aware Radzen Spec Kit core.
