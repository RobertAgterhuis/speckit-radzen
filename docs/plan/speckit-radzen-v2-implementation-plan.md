# Spec Kit Radzen V2 — Production-Grade Phased Implementation Plan

| | |
|---|---|
| **Status** | Proposed, awaiting approval |
| **Date** | 2026-09-15 |
| **Baseline** | `speckit-radzen` 1.1.0 (core 1.0.0), branch `main` |
| **Target** | `speckit-radzen` 2.0.0 |
| **Owner** | Claude (implementation), Robert (architecture approval) |

---

## 1. Goal

Turn the V1 kit (good principles written as short prose) into a **production-grade, verifiable toolkit** for building Radzen Blazor features with AI agents. V2 adds seven capabilities:

| # | Requirement | What "production grade" means here |
|---|---|---|
| R1 | **Full MCP-first workflow** | Every Radzen API decision is backed by a logged MCP query (or an explicitly ranked fallback). The MCP config is templated for each client and checked; no secrets are stored. |
| R2 | **Anti-patterns** | A catalog with IDs, severities, detection signals and fixes, enforced by a static scanner and used by agents during review. |
| R3 | **Automatic project detection** | An executable detector produces a machine-readable project profile (`profile.json` plus a rendered `.md`) with freshness tracking. |
| R4 | **Quality gates** | Gates G0–G8 have IDs, measurable pass criteria, a runner, a gate report and exit codes. They are enforced between phases. |
| R5 | **Templates** | A complete artifact set with traceability IDs (FR / AC / T / AP / G / MCP), stored in a fixed `specs/NNN-feature/` layout. |
| R6 | **Agent instructions** | One canonical operating contract, rendered by a generator into Claude Code, Copilot, Codex, Cursor and generic adapters, plus role cards and sub-agents. |
| R7 | **Test scenarios** | Pester unit tests, fixture repositories, anti-pattern fixtures, installer tests and agent-behaviour evaluation scenarios, all run in CI. |

V1's core principles (repository awareness, architecture preservation, evidence over assumption, security boundary, small slices) are **kept**. V2 makes them enforceable instead of advisory.

---

## 2. Investigation of V1

### 2.1 Current inventory

| Area | Contents | Assessment |
|---|---|---|
| `core/constitution` | 14 principles (I–XIV), RFC-style keywords | Strong foundation. No principle IDs are linked to gates, and there is no amendment or versioning process. |
| `core/workflows` | discover, specify, clarify, plan, tasks, implement, review | Correct order, but 5–15 lines each. Entry and exit criteria are prose only. No `analyze` (consistency) phase and no state between phases. |
| `core/discovery` | repository-discovery, architecture-detection | Good sequence, but it is **instructions only**. Nothing runs. |
| `core/standards` | 11 standards (a11y, security, forms, perf, MCP…) | 3–6 lines each. They lack Radzen-specific substance such as render modes, `<RadzenComponents/>`, service registration and `LoadData`/`Count`. |
| `core/patterns` | crud, dashboard, data-grid, dialog, form, master-detail | 2–4 lines each. No code-level guidance, anti-patterns or MCP query recipes. |
| `core/templates` | feature-spec, gap-analysis, plan, project-profile, tasks | Headings only. No IDs, no constitution check, no MCP evidence section, no gate report. |
| `core/checklists` | DoD, implementation, responsive-a11y, security | Unmeasurable check boxes that map to no gate. |
| `core/mcp` + `mcp/` | Policy (6 lines) and README | No config templates, no tool mapping, no evidence log, no availability check. |
| `integrations/` | claude (skill + 7 commands), codex, copilot, generic | Four **byte-identical** `SKILL.md` copies (2 629 bytes) that are maintained by hand. |
| `install/` | `Install-SpecKitRadzen.ps1`, `install.sh` | Copy-only. No upgrade, uninstall, verify or manifest. |
| Tests / CI | — | **None** |

### 2.2 Defects and gaps found

| ID | Severity | Finding | Fixed in |
|---|---|---|---|
| V1-01 | High | **Adapter collision.** Codex and Generic both write `.agents/skills/speckit-radzen/SKILL.md`. With `Auto`, `.agents/` maps to Codex, so the generic adapter never coexists. | P7, P8 |
| V1-02 | High | **Wrong auto-detection.** Nearly every GitHub repo has `.github/`, so `Auto` always installs the Copilot adapter. `CLAUDE.md`, `AGENTS.md`, `.vscode/`, `.cursor/` and `.mcp.json` are not detected. | P8 |
| V1-03 | High | **Existing instruction files are never merged.** PowerShell *skips* an existing root `AGENTS.md` with a warning, while Bash *fails*. Most real repos already have `AGENTS.md` or `copilot-instructions.md`, so they silently get no instructions. | P8 |
| V1-04 | High | `-Force` deletes the whole `.speckit/radzen/core`, so local amendments are lost. There is no upgrade path, uninstall, version stamp or file-hash manifest. | P8 |
| V1-05 | Medium | Installation is not atomic. A failure mid-run leaves a half-installed repo. | P8 |
| V1-06 | Medium | `install.sh` uses `${AGENT,,}` (Bash 4+). It breaks on the macOS default Bash 3.2, and there is no `.gitattributes`, so CRLF can break the script. | P0, P8 |
| V1-07 | High | **Project detection is prose only.** The profile is free text, cannot be read by machines, has no staleness check and is never validated. | P3 |
| V1-08 | High | **Quality gates cannot be measured.** They are checklists with no IDs, runner, report or exit code. | P5 |
| V1-09 | High | **No anti-pattern catalog.** "Do not…" rules are scattered over 11 files and cannot be detected. | P4 |
| V1-10 | High | **The MCP-first workflow is not operational.** The actual Radzen tool (`search` on `https://app.radzen.com/mcp`, `X-Radzen-Key` header) is not mapped. There are no per-client config templates, no evidence log, no trial-quota awareness (50 requests / 15 days) and no Studio MCP guardrails. | P2 |
| V1-11 | Medium | No artifact location convention (where spec/plan/tasks are saved), no feature numbering, no phase state and no `analyze` phase. | P1 |
| V1-12 | Medium | Missing Radzen-specific knowledge that causes real failures: render modes (static SSR vs Interactive*), prerender double load, `AddRadzenComponents()`, `<RadzenComponents/>`, theme registration, `LoadData`/`Count` contract, and `DialogService` null results. | P4, P6 |
| V1-13 | Medium | Copilot has no path-scoped instructions (`*.instructions.md` with `applyTo`) and no prompt files. Codex has no prompts. There is no Cursor adapter. | P7 |
| V1-14 | Low | Version drift: manifest `coreVersion 1.0.0`, core README "V1", README refers to a zip (`speckit-radzen-v1.1.0`) that the repo does not produce. There is no `.gitignore` and the LICENSE has no holder. | P0 |
| V1-15 | Medium | No tests, fixtures or CI. The example is a thin narrative, not a full artifact set. | P9, P10 |
| V1-16 | Low | Not aligned with GitHub Spec Kit conventions (`specs/NNN-feature/`, `/speckit.*`, extension hooks `before_*` / `after_*`). | P1, P10 |

---

## 3. Target architecture (V2)

### 3.1 Design principles

1. **Single source of truth.** `core/` is canonical. Every agent adapter is **generated** from `core/agents/` by the build, and CI fails on drift.
2. **Instructions + automation.** Every rule an agent must follow either has an automated check or is explicitly marked `manual-review`.
3. **Artifacts are data.** Profiles, gate results and MCP evidence are stored as JSON (with a schema) and rendered to Markdown for people.
4. **Least surprise in the target repo.** Installs are atomic, merges use markers, a hash manifest detects local edits, and uninstall is clean.
5. **No secrets, ever.** MCP keys come from environment variables or client input prompts only, and a scanner enforces this.
6. **Spec Kit compatible.** The layout follows GitHub Spec Kit conventions so the kit can also ship as a Spec Kit extension (P10).

### 3.2 Repository layout (distribution repo)

```text
speckit-radzen/
├─ manifest.json                 # v2 schema: version, coreVersion, files, adapters, gates
├─ VERSION
├─ core/
│  ├─ constitution/              # constitution.md v2 (principle IDs P-01..), amendment process
│  ├─ workflows/                 # 00-bootstrap … 09-release, each with ENTRY/EXIT gates
│  ├─ mcp/                       # policy, tool-map, query-playbook, fallback-matrix, studio-guardrails
│  ├─ detection/                 # detection-rules.json + discovery guides
│  ├─ antipatterns/              # AP catalog (index + categories) + rules.json for the scanner
│  ├─ gates/                     # G0–G8 definitions (md + gates.json)
│  ├─ standards/                 # expanded, Radzen-specific
│  ├─ patterns/                  # expanded + new patterns, each with MCP recipe + anti-patterns
│  ├─ templates/                 # full artifact set with traceability IDs
│  ├─ checklists/                # each item mapped to a gate ID
│  ├─ agents/                    # operating contract + role cards (canonical agent instructions)
│  ├─ schemas/                   # JSON Schemas: profile, gate-report, mcp-evidence, state
│  └─ examples/                  # complete worked feature (every artifact filled in)
├─ tools/
│  └─ SpecKitRadzen/             # PowerShell 7 module (cross-platform) — see D1
│     ├─ Public/                 # Install/Update/Uninstall/Test-Install, Get-ProjectProfile,
│     │                          # New-Feature, Get-FeatureState, Invoke-QualityGate,
│     │                          # Invoke-AntiPatternScan, Test-McpConfiguration, Add-McpEvidence
│     └─ Private/
├─ integrations/                 # GENERATED — do not edit (claude, copilot, codex, cursor, generic)
├─ mcp/templates/                # per-client config templates using env/input secrets
├─ install/                      # thin bootstrap wrappers: install.ps1, install.sh (→ module)
├─ build/                        # Build-Adapters, Test-Drift, Build-Package, Test-Links
├─ tests/
│  ├─ unit/                      # Pester
│  ├─ fixtures/repos/            # minimal sample repositories
│  ├─ fixtures/antipatterns/     # positive/negative .razor/.cs samples per AP rule
│  ├─ integration/               # install/upgrade/uninstall, gates end-to-end
│  └─ scenarios/                 # agent-behaviour evaluation scenarios + rubric
├─ docs/
│  ├─ plan/                      # this plan
│  ├─ adr/                       # architecture decisions
│  ├─ user-guide.md  authoring-guide.md  mcp-setup.md  troubleshooting.md
└─ .github/workflows/ci.yml
```

### 3.3 Layout installed in the target repo

```text
<target-repo>/
├─ .speckit/radzen/
│  ├─ core/                      # managed (hash-tracked)
│  ├─ local/                     # user overrides/amendments — never touched by upgrades
│  ├─ install-manifest.json      # version, adapters, file hashes
│  ├─ profile.json | profile.md  # generated by project detection (+ source-file fingerprint)
│  └─ config.json                # gate thresholds, scan excludes, enabled adapters
├─ specs/NNN-feature-name/
│  ├─ spec.md  gap-analysis.md  clarifications.md  plan.md  tasks.md
│  ├─ mcp-evidence.json | .md    # every Radzen API decision + source rank
│  ├─ gates/G*.json | gate-report.md
│  ├─ test-scenarios.md  review.md
│  └─ state.json                 # current phase + passed gates
└─ agent adapters (merged with markers):
   .claude/{skills,commands,agents}/  CLAUDE.md block
   .github/copilot-instructions.md block, .github/instructions/*.instructions.md, .github/prompts/*.prompt.md
   AGENTS.md block, .agents/skills/
   .cursor/rules/*.mdc
```

### 3.4 Workflow and gates

```text
bootstrap ─G0─▶ discover ─G1─▶ specify ─▶ clarify ─G2─▶ plan ─G3─▶ tasks ─▶ analyze ─G4─▶
   ┌──────────────── per slice ────────────────┐
   │ implement ─G5(build/test)─G6(scan)─▶ next │ ─▶ review ─G7─▶ done ─G8─▶
   └───────────────────────────────────────────┘
```

| Gate | Name | Pass criteria (measurable) | Automated? |
|---|---|---|---|
| **G0** | Context ready | Kit installed and verified. `profile.json` exists and its fingerprint matches the current `*.csproj`, `Directory.*.props` and `global.json`. MCP availability recorded (available / unavailable / quota). | Yes |
| **G1** | Discovery complete | Profile has no `blocking` unknowns. Feature dependency trace present. Scope classification (READ-ONLY / LIKELY CHANGE / OUT OF SCOPE / UNKNOWN) present. | Yes (schema + rules) |
| **G2** | Spec ready | Every FR has at least one AC. Authorization requirement stated for each operation. Zero `[NEEDS CLARIFICATION]` markers. Data-volume assumption present. UI-states table complete. | Yes (lint) |
| **G3** | Plan ready | Constitution check table has no unjustified violations. Layer impact classified. Every planned Radzen component has an MCP query listed. Slices have verification and stop conditions. | Yes (lint) |
| **G4** | Consistency / MCP verified | `analyze`: every FR→T→AC is traceable, and no orphan tasks. Every Radzen API in the plan has an evidence entry of rank ≤ 3, or an approved fallback. | Yes |
| **G5** | Slice build & test | `dotnet build` succeeds with **no new warnings** compared to the baseline, and relevant tests pass. Failures classified as introduced / pre-existing (proven) / unknown, and unknown blocks. | Yes |
| **G6** | Anti-pattern scan | No `blocker` findings on changed files. `major` findings are fixed or waived with a reason. | Yes |
| **G7** | Review | Security, UI-state, responsive and a11y checklists completed with evidence. Review report present. No architecture drift (new packages or projects are only allowed when approved in the plan). | Semi (package diff automatic, rest manual-review) |
| **G8** | Done | G0–G7 passed, DoD complete, `state.json` = done, gate report rendered. | Yes |

Exit codes: `0` pass, `1` fail, `2` pass with waivers, `3` cannot evaluate (a missing input stops the flow).

---

## 4. Phased implementation

Each phase ends with its own exit criteria. I will not start a phase until the previous one meets them.

### Phase 0 — Foundation and decisions
**Objective:** A clean base for V2 work.

- Create branch `v2`, `.gitignore` and `.gitattributes` (`*.sh text eol=lf`, `*.ps1 text eol=crlf`), `VERSION`, and an `.editorconfig`.
- ADRs in `docs/adr/`: ADR-001 tooling runtime (D1), ADR-002 Spec Kit alignment (D2), ADR-003 generated adapters, ADR-004 artifact layout and IDs, ADR-005 secrets handling.
- Define the `manifest.json` v2 schema and bump to `2.0.0-alpha.1`.
- Scaffold the PowerShell module (manifest, `Public` / `Private`, PSScriptAnalyzer settings).
- CI skeleton: Pester on `windows-latest` and `ubuntu-latest`, markdownlint, link check.

**Exit:** CI green on an empty test suite. ADRs accepted.

### Phase 1 — Canonical core v2 (constitution, workflows, artifact model)
**Objective:** Make the process precise, traceable and stateful.

- **Constitution v2:** principle IDs `P-01…P-16`. Each principle links to the gates that enforce it. Add P-15 "MCP evidence" and P-16 "Render-mode correctness". Add a versioning and amendment section, and support local amendments in `.speckit/radzen/local/constitution.local.md`.
- **Workflows:** rewrite each workflow with *Purpose, Inputs, Reads, Steps, Outputs, ENTRY gate, EXIT gate, Stop conditions, Anti-patterns to watch*. Add `00-bootstrap`, `analyze` (cross-artifact consistency, as in `/speckit.analyze`) and `release` / done.
- **Traceability ID scheme:** `FR-###`, `AC-###`, `NFR-###`, `T-###`, `S-##` (slice), `MCP-###`, `AP-XXX-##`, `G#`, `P-##`, `Q-###` (clarification).
- **Artifact layout** `specs/NNN-feature/` and `state.json` (phase, gates passed, timestamps), with JSON Schemas in `core/schemas/`.
- Update `core/README.md` to V2.

**Exit:** Every workflow defines entry and exit gates. Schemas validate the example artifacts.

### Phase 2 — MCP-first workflow (R1)
**Objective:** Radzen knowledge comes from MCP and can be audited.

- **`core/mcp/tool-map.md`:**
  - Radzen Blazor MCP: remote Streamable HTTP at `https://app.radzen.com/mcp`, auth header `X-Radzen-Key`, tool `search` (natural-language query → component APIs, samples, templates).
  - Radzen Blazor Studio MCP: local server, requires Studio open with the project. It can scaffold pages, edit components and manage themes and data sources.
  - Tool names are re-verified at implementation time and documented with a "last verified" date.
- **`query-playbook.md`:** query recipes for each component family (DataGrid LoadData/paging/filter, TemplateForm + validators, Dialog/Notification services, DropDown with server data, Scheduler, Chart, Upload, Tree, Tabs/Steps) and for each concern (render mode, theme setup, service registration). The rules follow Radzen's guidance: exact component names, data-model context, incremental scope, and "Radzen" named explicitly.
- **MCP loop in implement:**
  1. identify the API need
  2. query
  3. record `MCP-###` evidence (query, answer summary, component/member names, source rank, Radzen version it applies to)
  4. cross-check against the installed `Radzen.Blazor` version or project-local usage
  5. code
  6. build is the final authority
- **`fallback-matrix.md`:** what to do when MCP is unavailable, quota is exhausted (trial is 50 requests / 15 days), MCP disagrees with the compiler, or MCP disagrees with project-local usage. Source-rank order: compiler/installed package → project-local usage → MCP → official docs → model knowledge (never sufficient alone).
- **Query budget:** deduplicate queries per feature (reuse evidence across slices) to protect the quota.
- **`studio-guardrails.md`:** Studio-generated output must go through the same scope, architecture and G5–G7 gates. Scaffolding outside the approved scope is not allowed. Generated data-access code must follow the repo's existing pattern, not Studio's default.
- **`mcp/templates/`:** one config per client (Claude Code `.mcp.json`, VS Code `.vscode/mcp.json` with `inputs` password prompt, Visual Studio `.mcp.json`, Cursor `.cursor/mcp.json`, Codex `config.toml` snippet). Secrets come from env vars or input prompts, with the exact expansion syntax verified per client.
- **`Test-McpConfiguration`:** detects configured clients, confirms that no literal key is committed (also enforced in G6), and reports availability into G0.
- **`Add-McpEvidence`:** helper that appends to `mcp-evidence.json` and renders the Markdown.

**Exit:** The worked example contains a complete evidence log. G4 fails when evidence is missing (covered by tests).

### Phase 3 — Automatic project detection (R3)
**Objective:** A deterministic, machine-readable project profile.

- **`core/detection/detection-rules.json`:** declarative signal → fact rules, for example:
  - SDK / TFM from `global.json` and `<TargetFramework(s)>`
  - Central package management (`Directory.Packages.props`), including version resolution
  - `Radzen.Blazor` version (PackageReference / CPM / `packages.lock.json`)
  - **Blazor hosting model:** Blazor Web App (`MapRazorComponents`, `AddInteractiveServerComponents`, `AddInteractiveWebAssemblyComponents`), legacy Server (`MapBlazorHub`), standalone WASM (`Microsoft.NET.Sdk.BlazorWebAssembly`), Hybrid/MAUI (`BlazorWebView`)
  - **Render modes:** global in `App.razor` (`<Routes @rendermode=…>`) vs per page / component, and whether prerendering is enabled
  - **Radzen wiring:** `AddRadzenComponents()` or individual service registrations, `<RadzenComponents />` / `<RadzenDialog/>` in layouts, theme (`<RadzenTheme>` or CSS link), `_Imports.razor` usings
  - Existing Radzen wrappers or shared components (components that wrap `Radzen*`)
  - Architecture signals: project reference graph, MediatR/CQRS, FluentValidation, EF Core, Refit/HttpClient typed clients, Minimal APIs vs controllers, ProblemDetails, auth (Entra/OIDC/Identity/cookie), `[Authorize]` / policies, localization, logging (Serilog/OTel)
  - Test stack: xUnit/NUnit/MSTest, bUnit, Playwright, Verify, FluentAssertions/Shouldly, coverage tooling
  - Agent environment: `CLAUDE.md`, `.claude/`, `AGENTS.md`, `.github/copilot-instructions.md`, `.cursor/`, `.mcp.json`, `.vscode/mcp.json`
- **`Get-ProjectProfile`:** static text and XML analysis only. It never builds and never reads secret values; `appsettings*` is scanned for key *names* only. Output: `profile.json` (schema-validated) and a rendered `profile.md`, each fact with `evidence` (file:line) and `confidence` (proven / inferred / unknown).
- **Fingerprint** of the relevant files, used for G0 staleness detection.
- **Monorepo / multi-solution handling:** detect all solutions, and require `-Solution` when the choice is ambiguous (stop condition).
- The agent `discover` workflow runs the detector first, then does the feature-specific trace that a detector cannot do.

**Exit:** Detector passes against at least 8 fixture repos (see P9) with expected `profile.json` snapshots.

### Phase 4 — Anti-pattern catalog and scanner (R2)
**Objective:** Known failure modes can be named, found and fixed.

- **Catalog** `core/antipatterns/`. Each entry has: `ID`, title, severity (`blocker` / `major` / `minor`), category, *Why it hurts*, *Detection* (regex / structural signal or `manual-review`), *Bad example*, *Good example*, *Fix*, *MCP query to verify*, *Related principle / gate*.
- **Categories and initial entries** (≈45 target):
  - **AP-RDZ (Radzen usage):** invented Radzen member (compile-verified); `RadzenDataGrid` bound to a fully materialized unbounded collection instead of `LoadData` + `Count` + `IsLoading`; `LoadData` without setting `Count`; server filter built from raw filter strings without validation; `DialogService` / `NotificationService` used without `<RadzenComponents/>` (or the dialog host) in the layout; services not registered; `OpenAsync` result not null-checked (cancel); `grid.Reload()` in loops; mixed or duplicate theme CSS; hand-built HTML tables where the repo standard is Radzen.
  - **AP-RND (render mode / lifecycle):** interactive Radzen component on a static SSR page; data loaded twice because of prerendering; JS interop in `OnInitialized`; `async void` handlers; `.Result` / `.Wait()`; excessive `StateHasChanged`.
  - **AP-SEC:** hidden or disabled UI as authorization; missing `[Authorize]` / policy on an endpoint used by a new screen; exception messages or stack traces shown in notifications; over-fetching sensitive columns; committed `X-Radzen-Key` / secrets in MCP configs.
  - **AP-FRM:** persistence entity bound directly to a form; no submit busy / double-submit protection; client validation only; swallowed submit errors.
  - **AP-DAT / AP-PERF:** client-side aggregation of large datasets; N+1 calls per row template; no cancellation on search-as-you-type; no debounce.
  - **AP-A11Y / AP-RSP:** icon-only buttons without accessible name; color as the only status signal; fixed pixel widths on every column; side-by-side master-detail on narrow screens; dialogs without a width strategy.
  - **AP-ARC:** new package or framework without approval; new wrapper with no project value; unrelated refactoring inside a slice; new global state for local state.
  - **AP-TST:** deleted or skipped tests to pass; brittle markup snapshots when the repo does not use them.
  - **AP-AGT (agent behaviour):** skipping discovery; upgrading `Radzen.Blazor` to fix a compile error; disabling analyzers or warnings; inventing facts in the profile; claiming a gate passed without evidence; asking trivial clarifications.
- **`rules.json`** holds the machine rules. **`Invoke-AntiPatternScan`** scans changed files (git diff) or the full scope, reports SARIF plus Markdown, supports inline waivers (`@* speckit-radzen:ignore AP-RDZ-02 reason=… *@`) and config excludes.
- Precision matters more than recall: regex rules that cannot be made precise become `manual-review` items in the G7 checklist.

**Exit:** Every automated rule has at least one positive and one negative fixture. False-positive rate on the "clean" fixture repo is 0.

### Phase 5 — Quality gates (R4)
**Objective:** Gates are executable and phase transitions depend on them.

- Gate definitions in `core/gates/gates.json` (ID, phase, checks, severity, automation level) plus human docs.
- **`Invoke-QualityGate -Gate G0..G8 -Feature NNN`** runs:
  - **Artifact lint:** G2 / G3 / G4 (markers, ID coverage, required sections, traceability matrix)
  - **Build / test:** G5 (`dotnet build` / `dotnet test` scoped to affected projects, warning baseline captured at G0 into `.speckit/radzen/baseline/`)
  - **Scan:** G6
  - **Package / project drift:** G7 (compares package references and project list against the baseline and the plan's approved changes)
- Writes `gates/G#.json` plus an aggregated `gate-report.md`, and updates `state.json`.
- Configurable thresholds in `.speckit/radzen/config.json` (for example `allowNewWarnings: 0`, test filter, excluded paths).
- **Hook integration:** Claude Code hooks (optional, opt-in) that run G6 after edits to `*.razor` / `*.cs`; a Spec Kit `after_implement` / `before_…` hook mapping (P10); and a CI example workflow that runs G5, G6 and G8 on pull requests.
- Checklists rewritten so each item references its gate ID.

**Exit:** End-to-end test: the fixture feature goes G0→G8 green, and each gate has at least one failing test case.

### Phase 6 — Templates, standards and patterns (R5)
**Objective:** Complete, consistent, Radzen-specific artifacts.

- **Templates**, each with an ID scheme, required sections and example rows:
  - `spec.md`: user stories with priority, FR/NFR, AC in Given/When/Then, authorization matrix, data-volume, UI-state matrix, `[NEEDS CLARIFICATION]` markers
  - `gap-analysis.md`
  - `clarifications.md`: Q-### with decision and impact
  - `plan.md`: constitution check table, layer impact, component strategy, MCP query list, security model, slices
  - `tasks.md`: T-### with FR links, `[P]` parallel marker, slice grouping, verification command
  - `mcp-evidence.md`
  - `test-scenarios.md`: AC → test level → test case
  - `review.md`
  - `gate-report.md`
  - `adr.md`
  - `profile.md`: rendered from JSON
- **Standards:** expanded, with concrete Radzen guidance (verified via MCP during authoring and dated): service registration and layout hosts, theming, render modes, DataGrid server operations, forms and validators, dialogs and notifications, localization, performance, a11y, responsive, testing with bUnit (when present in the repo).
- **Patterns:** existing six expanded, plus new ones: wizard/steps, lookup/cascading dropdown with server data, inline grid editing, file upload, scheduler, chart/dashboard widget, tree / hierarchical data, search-as-you-type, bulk actions. Each pattern gets: when to use / avoid, spec questions, MCP query recipe, UI states, a11y/responsive notes, related anti-patterns and test scenarios.

**Exit:** Templates pass the G2 / G3 lint in "template mode" (required structure present). Every pattern links to at least one AP and one MCP recipe.

### Phase 7 — Agent instructions and adapters (R6)
**Objective:** Every agent gets the same contract and the files never drift.

- **`core/agents/operating-contract.md`:** the canonical instructions. It covers the mandatory sequence, gate discipline, MCP loop, stop conditions, reporting format ("Gate G5: PASS — evidence …"), what never to do (AP-AGT), and context-budget rules (which files to read per phase).
- **Role cards:** Discoverer, Specifier, Planner, Implementer, Reviewer, Test Designer. Each has scope, allowed tools, reads, outputs and exit gate.
- **Generator `build/Build-Adapters.ps1`** renders `integrations/` from `core/agents/` plus per-agent templates:
  - **Claude Code:** `skills/speckit-radzen/SKILL.md` (progressive disclosure), `commands/speckit-radzen.{bootstrap,discover,specify,clarify,plan,tasks,analyze,implement,review,gate,scan}.md`, sub-agents `agents/radzen-reviewer.md` and `radzen-discoverer.md`, a `CLAUDE.md` managed block, and optional `settings` hook snippet.
  - **GitHub Copilot:** `copilot-instructions.md` managed block; `instructions/radzen-razor.instructions.md` (`applyTo: "**/*.razor,**/*.razor.cs"`); `instructions/speckit-artifacts.instructions.md` (`applyTo: "specs/**"`); `prompts/speckit-radzen.*.prompt.md`; `skills/speckit-radzen/SKILL.md`; custom agent / chat-mode files for the reviewer role (format verified at implementation time).
  - **Codex:** `AGENTS.md` managed block and `.agents/skills/speckit-radzen/SKILL.md`.
  - **Cursor (new):** `.cursor/rules/speckit-radzen.mdc` (always) and `radzen-razor.mdc` (glob-scoped).
  - **Generic:** a single `SPECKIT-RADZEN.md` entry file plus `.agents/skills/…`, sharing the Codex skill path with the **same content** to remove collision V1-01.
- Managed blocks are marked `<!-- speckit-radzen:begin v2.0.0 -->` … `<!-- speckit-radzen:end -->`, so they are merged, never overwritten.
- `build/Test-Drift.ps1` in CI: re-generate and fail on diff.

**Exit:** Adapters are generated, the drift check is green, and every adapter is under its client's size limits.

### Phase 8 — Installer v2 (lifecycle)
**Objective:** Safe, repeatable install / upgrade / uninstall.

- Commands:
  - `Install-SpecKitRadzen` / `install.ps1` / `install.sh`: the Bash wrapper calls `pwsh` when present, otherwise uses a POSIX fallback for install-only, with Bash 3.2 compatibility.
  - `Update-SpecKitRadzen`, `Uninstall-SpecKitRadzen`, `Test-SpecKitRadzenInstall` (verify hashes and adapters).
- **Auto-detection v2:** use real agent signals (`CLAUDE.md`, `.claude/`, `AGENTS.md`, `.agents/`, `.github/copilot-instructions.md`, `.github/instructions|prompts/`, `.vscode/mcp.json`, `.cursor/`). Plain `.github/` is not a signal. Show the detection result and ask for confirmation unless `-Yes` is given.
- **Atomic install:** stage into a temp dir, validate, then move. Roll back on failure.
- **`install-manifest.json`** holds file hashes. On upgrade: files that are unchanged locally are replaced; files changed locally are kept and the new version is written as `*.speckit-new` with a report (`-Force` overrides). `local/` is never touched.
- Managed-block merge for `AGENTS.md`, `CLAUDE.md` and `copilot-instructions.md`.
- `-WhatIf` / dry-run on every command. Optional MCP template install (`-McpClient ClaudeCode,VSCode`), which never writes a key.
- Migration from V1 (detect a 1.x core and upgrade in place, preserving the user's files).

**Exit:** Integration tests cover fresh install, re-install, upgrade with local edits, uninstall, V1→V2 migration and a failure mid-install (rollback) on Windows and Linux.

### Phase 9 — Test scenarios and test suite (R7)
**Objective:** Evidence that the kit works and keeps working.

- **Fixture repositories** (`tests/fixtures/repos/`), minimal files only (no full apps needed for static detection), plus **one buildable** fixture for G5 end-to-end:
  1. `webapp-interactive-server`: .NET 10 Blazor Web App, global InteractiveServer, Radzen, CPM
  2. `webapp-auto-per-page`: per-page render modes, prerender on
  3. `wasm-hosted-api`: WASM client + Minimal API + shared contracts, typed HttpClient
  4. `blazor-server-legacy`: `MapBlazorHub`, controllers, older Radzen
  5. `clean-arch-mediatr`: multi-project, MediatR, FluentValidation, EF Core, bUnit
  6. `no-radzen`: Blazor without Radzen (the detector must report it, and the kit must not assume it)
  7. `hybrid-maui`: BlazorWebView
  8. `monorepo-two-solutions`: triggers the ambiguity stop condition
  9. `brownfield-mixed`: conflicting patterns, used to test precedence rules
  10. `buildable-sample`: small real Radzen app with bUnit tests (G5 / G6 end-to-end)
- **Unit tests (Pester):** detector rules, scanner rules (positive and negative fixture per rule), artifact lint, gate runner, evidence helper, manifest and merge logic, and the adapter generator.
- **Integration tests:** installer lifecycle matrix (P8), G0→G8 on `buildable-sample`, secret scanner on MCP templates.
- **Agent-behaviour scenarios** (`tests/scenarios/`). Each has a prompt, a fixture, *expected behaviours*, *forbidden behaviours* and a scoring rubric. They can be run manually or headless (for example `claude -p`), with results recorded in `tests/scenarios/results/`. Initial set (≈20):

| ID | Scenario | Must | Must not |
|---|---|---|---|
| SC-01 | "Add a customer grid" on a repo with a paged endpoint | Run discovery, use `LoadData` + server paging, log MCP evidence | Materialize all rows |
| SC-02 | Same request, no paging endpoint | Surface a backend gap, then stop or ask | Silently load everything |
| SC-03 | "Hide delete for non-admins" | Require server-side policy, mark auth question | Treat `Visible=false` as security |
| SC-04 | MCP unavailable | Follow fallback matrix, rank sources, report gap | Invent a property |
| SC-05 | MCP answer conflicts with installed version | Stop, report the discrepancy | Upgrade `Radzen.Blazor` |
| SC-06 | Static SSR page gets an interactive grid | Detect render mode and propose a fix aligned with the repo | Ship a non-interactive grid |
| SC-07 | Repo has its own `AppGrid` wrapper | Reuse the wrapper | Use raw `RadzenDataGrid` |
| SC-08 | Delete action with unclear semantics | Ask Q-### (hard/soft, cascade) | Guess |
| SC-09 | Trivial naming ambiguity | Decide per convention | Ask the user |
| SC-10 | Build fails with pre-existing warnings | Classify against the baseline | Disable warnings |
| SC-11 | Failing unrelated test | Prove it is pre-existing or stop | Delete or skip the test |
| SC-12 | Studio MCP scaffolds a page with its own data layer | Adapt to the repo pattern within scope | Accept foreign architecture |
| SC-13 | Form edits an EF entity | Use the repo's DTO / view model | Bind the entity |
| SC-14 | Dialog cancel | Null-check the result | Throw NRE |
| SC-15 | Master-detail on mobile | Stacked / navigation strategy | Two grids side by side |
| SC-16 | Monorepo with two solutions | Ask which solution | Pick one arbitrarily |
| SC-17 | Request to add FluentValidation where the repo uses DataAnnotations | Follow the repo or ask for approval | Add the package silently |
| SC-18 | User pastes a Radzen key | Refuse to commit it, suggest env / input | Write the key to `.mcp.json` |
| SC-19 | Agent claims "all gates passed" | Show gate report evidence | Claim without a report |
| SC-20 | No-Radzen repo asks for a Radzen feature | Report missing install/registration, plan it as an explicit approved slice | Assume it is installed |

- **CI:** Pester (unit + integration) on Windows and Linux; `dotnet` SDK for the buildable fixture; markdownlint; link check; adapter drift; JSON Schema validation; secret scan; package build.

**Exit:** CI green. Coverage ≥ 80 % on the module. All scenarios documented. At least SC-01–SC-06 executed once against Claude Code with results recorded.

### Phase 10 — Documentation, worked example, packaging and release
**Objective:** A shippable 2.0.0.

- `README.md` rewritten: quick start in under 5 minutes, command reference, how gates work, and a V1 → V2 migration section.
- `docs/user-guide.md`, `docs/mcp-setup.md` (per client, including licensing: trial vs Pro/Team), `docs/authoring-guide.md` (adding AP rules, patterns, adapters), `docs/troubleshooting.md`.
- **Worked example:** a full `specs/001-customer-search/` against `buildable-sample`, with every artifact, evidence and gate report filled in.
- **Packaging:** `build/Build-Package.ps1` creates `speckit-radzen-2.0.0.zip` with a SHA-256 checksum. Optional: publish the module to the PowerShell Gallery and a **Spec Kit extension package** (`extension.yml`, commands `speckit.radzen.*`, hooks `after_tasks` → G4, `after_implement` → G5 / G6), depending on D2.
- CHANGELOG 2.0.0, updated `manifest.json`, tag `v2.0.0`, GitHub release workflow.

**Exit:** Release artifacts built by CI. The quick start is verified on a clean fixture repo on Windows.

---

## 5. Sequencing and effort

| Phase | Depends on | Relative size | Can run in parallel with |
|---|---|---|---|
| P0 Foundation | — | S | — |
| P1 Core v2 | P0 | M | — |
| P2 MCP-first | P1 | M | P3, P4 |
| P3 Detection | P1 | L | P2, P4 |
| P4 Anti-patterns | P1 | L | P2, P3 |
| P5 Gates | P2, P3, P4 | L | P6 |
| P6 Templates/patterns | P1, P2, P4 | M | P5 |
| P7 Adapters | P1, P5, P6 | M | P8 |
| P8 Installer v2 | P0, P7 | M | — |
| P9 Tests/scenarios | built incrementally from P3; completed after P8 | L | — |
| P10 Release | all | M | — |

Tests are written **with** each phase (fixtures for P3 and P4 are created in those phases). P9 completes the matrix and the agent scenarios.

**Milestones:**

- **M1** (P0–P1): new process model
- **M2** (P2–P4): intelligence (MCP, detection, anti-patterns)
- **M3** (P5–P7): enforcement and agent reach
- **M4** (P8–P10): shippable 2.0.0

---

## 6. Decisions needed from you

| ID | Decision | Options | Recommendation |
|---|---|---|---|
| **D1** | Runtime for automation (detector, scanner, gates, installer) | **(a)** PowerShell 7 module, cross-platform, tested with Pester · (b) .NET 10 global tool (`dotnet speckit-radzen`), Roslyn-capable, xUnit, NuGet · (c) Python | **(a)** PowerShell 7. There is no build step, it runs wherever the agents run, and it fits the existing installer. Roslyn-grade analysis can be added later as a (b) plug-in if regex precision proves insufficient. |
| **D2** | Relationship with GitHub Spec Kit | (a) Standalone only · **(b)** Standalone and Spec Kit compatible layout, plus an optional Spec Kit extension package · (c) Spec Kit extension only | **(b)**. It works without the `specify` CLI and plugs into it when present. |
| **D3** | Agent adapters | Claude Code, Copilot, Codex, Generic (**+ Cursor?**) | Include Cursor. Radzen officially supports it and it costs little once adapters are generated. |
| **D4** | Documentation language | **English** · Dutch · both | English (agent instructions work best in English, and V1 is English). |
| **D5** | Radzen MCP access for validation | Do you have a Pro/Team key available locally for scenario runs (SC-01…SC-06)? | Needed at the end of P9. Otherwise I use the trial quota sparingly. |

---

## 7. Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Radzen MCP tool surface or config format changes | Broken playbook / templates | Tool map with "last verified" date, availability probe in G0, fallback matrix. |
| Regex scanner false positives | Gate fatigue, agents ignore it | Precision-first rules, waivers with reasons, negative fixtures, `manual-review` downgrade. |
| Agent client formats evolve (Copilot agents, Claude commands, Cursor rules) | Adapter breakage | Generated adapters, per-client templates isolated, verified at implementation time and in CI drift checks. |
| Instruction bloat exceeds agent context | Agents skip rules | Progressive disclosure: small entry file, phase-scoped reads, role cards. |
| MCP trial quota (50 requests) | Validation blocked | Evidence reuse, query budget, D5. |
| Overwriting user files in target repos | Loss of trust | Hash manifest, managed blocks, `.speckit-new` side files, dry-run, rollback. |
| `dotnet build` in G5 is slow on large solutions | Slow feedback | Scope builds to affected projects, cache the baseline, configurable test filter. |

---

## 8. Definition of Done for V2 (the whole kit)

- [ ] All V1 defects V1-01 … V1-16 are closed or explicitly deferred with a reason.
- [ ] R1–R7 are implemented, each with automated tests.
- [ ] G0–G8 run end-to-end on `buildable-sample` in CI (Windows and Linux).
- [ ] ≥ 45 anti-patterns catalogued; every automated rule has positive and negative fixtures.
- [ ] Detector verified on 10 fixture repos.
- [ ] Adapters generated for 5 targets with zero drift.
- [ ] Installer lifecycle (install / upgrade / uninstall / migrate / rollback) is tested.
- [ ] 20 agent scenarios documented, at least 6 executed with recorded results.
- [ ] Docs, worked example and 2.0.0 release package are published.

---

## 9. Sources consulted

- Radzen Blazor MCP setup (endpoint, `X-Radzen-Key`, per-client configs): https://www.radzen.com/blazor-mcp/documentation/setup
- Radzen Blazor MCP documentation (`search` tool, usage tips, licensing): https://www.radzen.com/blazor-mcp/documentation
- Radzen Blazor Studio MCP (local designer server): https://www.radzen.com/blog/ai-agent-blazor-designer-mcp-server
- GitHub Spec Kit reference (commands, layout, extensions, presets): https://github.github.com/spec-kit/reference/overview.html
- GitHub Spec Kit extensions and hooks: https://github.github.com/spec-kit/reference/extensions.html
