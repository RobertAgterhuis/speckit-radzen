# ADR-0003: Agent adapters are generated from one source

- **Status:** Accepted (2026-09-15)

## Context

V1 shipped four byte-identical `SKILL.md` files maintained by hand, and Codex and Generic adapters wrote to the same path.

## Decision

- Canonical agent instructions live in `core/agents/`.
- `build/Build-Adapters.ps1` renders `integrations/<agent>/` for Claude Code, GitHub Copilot, Codex, Cursor and Generic from those sources plus per-agent templates in `build/adapter-templates/`.
- `integrations/` is generated output and is committed so that the distribution works without running the build. CI runs `build/Test-Drift.ps1` and fails if regeneration changes anything.
- Shared root instruction files (`AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`) are never overwritten. The installer merges a managed block delimited by `<!-- speckit-radzen:begin -->` / `<!-- speckit-radzen:end -->`.
- Codex and Generic share `.agents/skills/speckit-radzen/SKILL.md` with identical content, so installing both is safe.

## Consequences

Editing files under `integrations/` directly is pointless; the authoring guide says so and a header comment in each generated file repeats it.

## Addendum (2026-09-16): dot-folder names in the distribution

Adapter folders are stored as `dot-claude`, `dot-github`, `dot-agents` and `dot-cursor` inside `integrations/<agent>/`. The installer maps `dot-<name>` to `.<name>` in the target repository. Reasons: the distribution repository must not load its own adapters when an agent works on the kit itself, and some tooling (including remote file bridges) refuses to write into dot-folders.
