# MCP Policy

## Capabilities

| Server | Role | Required? |
|---|---|---|
| **Radzen Blazor MCP** (remote) | Current component knowledge: APIs, properties, events, enums, binding, samples, templates | Required whenever a feature needs Radzen API knowledge; see fallback matrix when unavailable |
| **Radzen Blazor Studio MCP** (local) | Design-time actions in an open Studio project: scaffold pages, edit components, themes, data sources | Optional; subject to `studio-guardrails.md` |

Details: `tool-map.md`.

## Policy

1. **MCP is a knowledge and execution source, not an architecture source.** Repository evidence and the approved specification govern what is built and how it fits the codebase.
2. **MCP first.** Before writing or changing code that uses a Radzen component, member or service, check the evidence log; if the API is not there, query the Radzen Blazor MCP (`mcp-workflow.md`).
3. **Log everything that informs code.** Every answer that informs a decision becomes an `MCP-###` entry (`speckit-radzen evidence add`). Unlogged knowledge does not count at G4.
4. **The compiler decides.** Source-rank order: installed package/compiler (1) → project-local usage (2) → Radzen MCP (3) → official Radzen documentation (4) → model knowledge (5). Rank 5 alone is never sufficient.
5. **Conflicts stop work.** When MCP and the installed version or project usage disagree, follow `fallback-matrix.md`. Never "fix" a conflict by changing the package version.
6. **Budget queries.** Re-use evidence across slices and features for the same component and Radzen version. Trial licences are limited (50 requests over 15 days at the time of writing); Pro/Team subscriptions are unlimited.
7. **No secrets in the repository.** Keys are provided through environment variables, client input prompts, or user-level configuration outside the repository (ADR-0005). `speckit-radzen mcp-check` and anti-pattern `AP-SEC-05` enforce this.
