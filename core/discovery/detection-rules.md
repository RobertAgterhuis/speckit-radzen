# Automatic Project Detection

`speckit-radzen detect` (module function `Get-ProjectProfile`) applies the declarative rules in `detection-rules.json` and a set of built-in analyzers to the repository. It never builds the code, never runs it, and never reads secret *values*.

## Output

- `.speckit/radzen/profile.json` — validated against `schemas/profile.schema.json`.
- `.speckit/radzen/profile.md` — rendered for people and agents.

Every fact has:

| Field | Meaning |
|---|---|
| `value` | The detected value |
| `confidence` | `proven` (direct evidence), `inferred` (indirect signal), `unknown` |
| `evidence` | `file:line` references |

## What is detected

| Section | Facts | Main signals |
|---|---|---|
| `repository` | solutions, projects, repository instructions, agent environment | `*.sln`, `*.slnx`, `*.csproj`, `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, `.cursor/`, `.mcp.json`, `.vscode/mcp.json` |
| `runtime` | SDK, target frameworks, central package management, nullable | `global.json`, `<TargetFramework(s)>`, `Directory.Packages.props`, `Directory.Build.props` |
| `blazor` | hosting model, render modes, prerendering | `MapRazorComponents`, `AddInteractiveServerComponents`, `AddInteractiveWebAssemblyComponents`, `MapBlazorHub`, `Microsoft.NET.Sdk.BlazorWebAssembly`, `BlazorWebView`, `@rendermode`, `prerender: false` |
| `radzen` | package + version, service registration, theme, script, component host, imports, wrappers | `Radzen.Blazor` reference (direct or CPM), `AddRadzenComponents`, `AddScoped<DialogService>`, `<RadzenTheme`, `Radzen.Blazor.js`, `<RadzenComponents`, `<RadzenDialog`, `@using Radzen` |
| `architecture` | project graph, UI-to-backend style, mediator, validation, mapping, persistence, API style, error handling, state, localization, logging | package references and code signals, see JSON |
| `security` | authentication, authorization style, policies | `AddAuthentication`, `AddMicrosoftIdentityWebApp`, `AddIdentity`, `[Authorize]`, `AddAuthorization(… AddPolicy`, `RequireAuthorization` |
| `testing` | frameworks, component testing, E2E, assertion, mocking, coverage | package references |
| `health` | Radzen wiring problems found | e.g. package present but no service registration |

## Freshness

The profile stores a `fingerprint`: a hash over the content of all `*.sln`, `*.slnx`, `*.csproj`, `Directory.*.props`, `global.json`, `Program.cs`, `App.razor`, `_Imports.razor` and `MainLayout.razor` files. G0 recomputes it; a mismatch means the profile is stale.

## Multiple solutions

When more than one solution exists and `.speckit/radzen/config.json` has no `solution` entry, the profile is written with `repository.solutionSelection = "ambiguous"` and G0 fails. Run `speckit-radzen detect -Solution path/to/App.sln` (this also stores the choice in `config.json`).

## Extending

Add a rule to `detection-rules.json`:

```json
{
  "id": "arch.mediator.mediatr",
  "fact": "architecture.mediator",
  "value": "MediatR",
  "kind": "package",
  "pattern": "^MediatR$",
  "confidence": "proven"
}
```

`kind` is one of `package` (package reference id regex), `file` (file name glob exists), `content` (regex in files matching `files`). See `schemas/detection-rules.schema.json`.
