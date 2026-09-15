# Spec Kit Radzen V1.1.0 — Portable Distribution

This package turns the V1 repository-aware Radzen specification core into a portable kit for multiple AI coding agents.

## Included

- Canonical V1 core under `core/`
- Claude Code skill + phase commands
- OpenAI Codex skill + `AGENTS.md` adapter
- GitHub Copilot skill + instruction adapter
- Generic Agent Skills adapter
- PowerShell and Bash installers
- Radzen MCP integration policy
- No embedded credentials

## Install into a repository

### PowerShell

```powershell
Expand-Archive .\speckit-radzen-v1.1.0.zip -DestinationPath .\speckit-radzen
.\speckit-radzen\speckit-radzen-v1.1.0\install\Install-SpecKitRadzen.ps1 `
    -Repository G:\Path\To\YourRepo `
    -Agent All
```

Use `-Agent Claude`, `Codex`, `Copilot`, `Generic`, `All`, or `Auto`.

`Auto` installs adapters for agent configuration directories already present in the target repository; when none are detected it installs the generic adapter.

### Bash

```bash
./speckit-radzen-v1.1.0/install/install.sh /path/to/repo all
```

## Result

The canonical rules are installed once:

```text
.speckit/radzen/core/
```

Agent-specific files are thin adapters that point back to that canonical core. This prevents three divergent copies of the standards.

Typical adapter locations:

```text
.claude/skills/speckit-radzen/SKILL.md
.claude/commands/speckit-radzen.discover.md
.claude/commands/speckit-radzen.specify.md
...
.agents/skills/speckit-radzen/SKILL.md
.github/skills/speckit-radzen/SKILL.md
```

## Claude phase commands

The package provides:

```text
/speckit-radzen.discover
/speckit-radzen.specify
/speckit-radzen.clarify
/speckit-radzen.plan
/speckit-radzen.tasks
/speckit-radzen.implement
/speckit-radzen.review
```

Exact UI/invocation behavior can vary by agent/client version; the underlying skill remains the same.

## Radzen MCP

Configure Radzen MCP separately in each AI client using the current Radzen/client instructions. Credentials are intentionally not included in this distribution.

The Spec Kit treats MCP as live Radzen technical knowledge, while repository evidence determines project architecture.

## Safe installation

The installer:
- does not delete unrelated `.claude`, `.agents`, or `.github` files;
- refuses to overwrite managed files by default;
- requires `-Force` / `FORCE=1` for replacement;
- does not modify application source code;
- does not install packages;
- does not store MCP credentials.

## Version
1.1.0
