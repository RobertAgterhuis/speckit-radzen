# Radzen Setup and Render Modes

Most "Radzen doesn't work" defects are wiring problems. Project detection reports them as health items (RDZ-H01…H07, RND-H01/H02).

## Required wiring (per host that renders Radzen components)

| Piece | Current convention (verify for the installed version) | Detected as |
|---|---|---|
| Package | `Radzen.Blazor` referenced by the project that contains the components (and by the WebAssembly client project when components render there) | `radzen.version` |
| Imports | `@using Radzen` and `@using Radzen.Blazor` in `_Imports.razor` | `radzen.imports` |
| Services | `builder.Services.AddRadzenComponents();` in every host (server **and** WebAssembly client) | `radzen.serviceRegistration` |
| Theme | `<RadzenTheme Theme="…" />` in the `<head>` of `App.razor` (older apps: a theme CSS link) — one mechanism only | `radzen.theme` |
| Script | `_content/Radzen.Blazor/Radzen.Blazor.js` after the Blazor script | `radzen.script` |
| Component host | `<RadzenComponents />` once in the main layout, with the app's render mode (older apps: `<RadzenDialog/>`, `<RadzenNotification/>`, `<RadzenContextMenu/>`, `<RadzenTooltip/>`) | `radzen.componentHost` |

Changing any of these is a **global** change: it needs its own FR and slice (constitution P-16).

## Render modes (.NET 8+ Blazor Web App)

- Pages without an interactive render mode are static SSR. Radzen events (`Click`, `Change`, `LoadData`, `ValueChanged`) do not fire there.
- Follow the repository: if `Routes` has a global `@rendermode`, pages inherit it; if render modes are per page, set the same mode the analogous page uses.
- `<RadzenComponents />` needs an interactive render mode matching the app, otherwise dialogs and notifications from interactive pages never appear.
- WebAssembly/Auto: components must live in (or be referenced by) the client project, and services must be registered in the client `Program.cs` too.

## Prerendering

- `OnInitializedAsync` runs twice with prerendering (prerender + interactive). Avoid duplicate backend calls: persist state (`PersistentComponentState` / `[PersistentState]` where available) or follow the repository approach.
- `RadzenDataGrid` `LoadData` is raised after the first interactive render, not during prerendering — a LoadData grid does not double-load, but renders empty during prerender. Show the loading state.
- JS interop is unavailable during prerendering; use `OnAfterRenderAsync(firstRender)` (AP-RND-03).

## Upgrades

Upgrading `Radzen.Blazor` is separate scope (P-04). Theme names, CSS paths and component parameters change between majors; an upgrade needs its own spec, MCP evidence for changed APIs, and a full G5 run.
