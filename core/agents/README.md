# Agent Instructions (canonical)

Source for every agent adapter. `build/Build-Adapters.ps1` renders `integrations/<agent>/` from these files; never edit generated adapters directly.

| File | Used for |
|---|---|
| `operating-contract.md` | Skill body (Claude Code, Copilot, Codex, generic), Cursor always-on rule, managed blocks in `CLAUDE.md` / `AGENTS.md` / `copilot-instructions.md` (condensed) |
| `razor-rules.md` | Path-scoped rules for Razor files (Copilot `applyTo`, Cursor `globs`) |
| `artifact-rules.md` | Path-scoped rules for `specs/**` |
| `phases.json` | Phase commands / prompt files |
| `roles/*.md` | Role cards; sub-agents / custom agents for discoverer and reviewer |

Paths inside role cards (`core/...`) are relative to the installed kit folder `.speckit/radzen/`.
