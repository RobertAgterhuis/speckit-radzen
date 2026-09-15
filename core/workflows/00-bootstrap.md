# Phase 00 — Bootstrap

**Purpose:** make sure the kit, the project profile and MCP access are in a known state before any feature work.

## Entry

- A feature request exists (a sentence is enough).

## Steps

1. Read `constitution/constitution.md` and, if present, `.speckit/radzen/local/constitution.local.md`.
2. Run `speckit-radzen verify-install`. If it fails, stop and report; do not repair managed files by hand.
3. Run `speckit-radzen detect`. It writes `.speckit/radzen/profile.json` and `profile.md`.
   - If it reports multiple solutions and none is configured, **stop** and ask which solution applies (P-13.8). Then run `speckit-radzen detect -Solution <path>`.
4. Run `speckit-radzen mcp-check` and note the result:
   - `available` — continue with the MCP-first loop.
   - `not-configured` / `unreachable` — continue under `mcp/fallback-matrix.md`, and tell the user.
   - `secret-in-repo` — **stop**. A literal key is in a tracked file (P-07).
   Also confirm in your own tool list that a Radzen MCP tool (for example `search` on the `radzen-blazor` server) is actually callable. Record `mcp.availability` with `speckit-radzen state -Feature NNN -McpAvailability available|unavailable|quota-exhausted`.
5. Create the feature folder: `speckit-radzen new-feature "<short name>"`. It returns the number `NNN`.
6. If this repository has never captured a build baseline, run `speckit-radzen baseline` (records current warnings so G5 can detect *new* ones). This builds the solution; if the build is broken before you start, record that in the feature's discovery notes.
7. Run `speckit-radzen gate G0 -Feature NNN`.

## Exit — G0

Kit verified, profile fresh, MCP availability recorded, feature folder created.

## Stop conditions

Install verification fails · ambiguous solution · secret found in MCP configuration.
