# MCP-First Workflow

This is the loop every agent runs whenever Radzen API knowledge is needed (plan and implement phases).

```text
need ─▶ evidence log hit? ──yes──▶ reuse MCP-### ─┐
          │ no                                   │
          ▼                                      │
   MCP available? ──no──▶ fallback-matrix.md ────┤
          │ yes                                  │
          ▼                                      ▼
   query (query-playbook.md) ─▶ record MCP-### ─▶ cross-check with installed version / project usage
                                                 │
                                   agree ◀───────┴───────▶ conflict ─▶ STOP (fallback-matrix.md)
                                     │
                                     ▼
                                   code ─▶ G5 build (compiler = rank 1) ─▶ evidence marked compile-verified
```

## 1. Identify the need

Be specific: component + member + purpose. "How does `RadzenDataGrid` report the total row count for server paging (`LoadData`, `Count`)?" is a need. "How do grids work?" is not.

## 2. Check the evidence log

`specs/NNN-*/mcp-evidence.md`, and evidence from earlier features in `specs/*/mcp-evidence.json` for the **same Radzen version** (see `.speckit/radzen/profile.md`). Reuse by citing the existing ID in your plan/task, or by recording a new entry with `-Source project` pointing at the earlier evidence.

## 3. Check availability

The feature's `state.json` has `mcp.availability` (recorded in phase 00). Also confirm the tool is in your tool list right now. If not available → `fallback-matrix.md`.

## 4. Query

Use `query-playbook.md`. One concern per query. Include:

- the exact component name(s);
- the data shape (type names and key properties);
- the interaction you need (server paging, inline edit, validation …);
- the render mode and the installed `Radzen.Blazor` version when behaviour might differ.

## 5. Record

```text
speckit-radzen evidence add -Feature NNN `
  -Component RadzenDataGrid -Members LoadData,Count,IsLoading `
  -Question "How to page on the server with a total count?" `
  -Query "RadzenDataGrid LoadData server-side paging with Count and IsLoading, TItem CustomerSummary" `
  -Source mcp -Tool search -Server radzen-blazor `
  -Summary "LoadData(LoadDataArgs) gives Skip/Top/OrderBy/Filter; set Count to the total; bind Data to the current page; IsLoading shows the loader."
```

Summaries are short and factual. Do not paste whole answers; do not paste licence keys or personal data.

## 6. Cross-check

- Is the member used elsewhere in this repository? Add `-ProjectEvidence path:line`.
- Does the answer depend on a Radzen version newer than the installed one? If unsure, the build in G5 decides; keep the entry `compileVerified: false` until then.

## 7. Code, then build

G5 marks evidence cited by the slice's tasks as `compileVerified` when the build succeeds. A compile error on a Radzen member means the evidence is wrong for this version: record a new entry with `-Status conflict` and follow the fallback matrix.

## What agents must never do

- Use a Radzen member that has no evidence entry (P-15).
- Treat an unrecorded MCP answer as evidence.
- Copy API shapes from other component libraries (MudBlazor, Syncfusion, Telerik, Fluent UI).
- Change the `Radzen.Blazor` version to make MCP guidance compile.
