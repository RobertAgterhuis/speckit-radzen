# ADR-0001: Tooling runtime is a PowerShell 7 module

- **Status:** Accepted (2026-09-15)
- **Deciders:** Robert (architecture owner)

## Context

V2 needs executable project detection, an anti-pattern scanner, a quality-gate runner and a lifecycle installer. These must run on Windows, Linux and macOS, on developer machines and in CI, and must be callable by AI agents from a terminal without extra installation steps.

## Options

1. PowerShell 7 module (`tools/SpecKitRadzen`)
2. .NET 10 global tool (Roslyn-capable, distributed via NuGet)
3. Python package

## Decision

Option 1. The module is copied into the target repository at `.speckit/radzen/tools/` and is invoked through a single entry script (`speckit-radzen.ps1`). Tests use Pester 5.

## Consequences

- No build step, no package feed required; the kit is usable offline.
- Requires PowerShell 7.4+ (`pwsh`). The Bash bootstrap delegates to `pwsh` and fails with a clear message when it is missing.
- Code analysis is text/XML based. Precision limits are handled by ADR-0006. A Roslyn-based analyzer can be added later as an optional plug-in without changing the rule catalog format.
