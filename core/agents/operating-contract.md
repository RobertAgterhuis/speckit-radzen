# Spec Kit Radzen — Agent Operating Contract

You build Radzen Blazor features in an existing repository. Follow this contract for any work that adds or changes Radzen UI, or a feature whose implementation needs Radzen UI changes.

`{{KIT}}` is the installed kit folder. `speckit-radzen` means `pwsh {{KIT}}/tools/speckit-radzen.ps1` (add `-Json` for machine-readable output).

## Non-negotiables

1. **Repository first.** Run `speckit-radzen detect` and read `.speckit/radzen/profile.md` before designing. Follow the closest analogous feature. Never introduce packages, layers, frameworks or wrappers that the plan does not approve.
2. **MCP first.** Before using any Radzen component, member or service, check the feature's `mcp-evidence.md`; if it is not there, query the Radzen Blazor MCP (`search` tool) and record the answer with `speckit-radzen evidence add`. Never invent Radzen APIs. Never copy APIs from other component libraries. The installed version and the compiler are the final authority.
3. **Gates are facts.** Move between phases with `speckit-radzen phase …`; run `speckit-radzen gate G#`. Report a gate as passed only when its result says so, and quote the result.
4. **Security at the trusted boundary.** Hidden or disabled UI is never authorization. Every sensitive operation has a server-side enforcement point.
5. **Small slices.** Implement one slice at a time; each slice passes G5 (build, no new warnings, tests) and G6 (anti-pattern scan).
6. **Stop, don't guess.** Stop and ask when: authorization is ambiguous; a Radzen API cannot be verified; patterns conflict; a change is outside approved scope; a failure cannot be classified; a dependency change is unapproved; destructive behaviour is unclear; the solution is ambiguous; a gate returns exit code 3; someone asks you to commit a secret.
7. **No secrets.** Never write licence keys or credentials to tracked files. The Radzen MCP key comes from `RADZEN_MCP_KEY` or a client input prompt.
8. **Never** upgrade or downgrade packages to make code compile, disable/skip/delete tests, suppress warnings or analyzers, swallow exceptions, or refactor unrelated code.

## Phases

| # | Phase | Do | Exit |
|---|---|---|---|
| 00 | bootstrap | `detect`, `mcp-check`, confirm the Radzen MCP tool is in your tool list, `new-feature`, `state -McpAvailability …`, `baseline` (once per repository) | `gate G0` |
| 01 | discover | trace the feature end-to-end; write `discovery.md` | `gate G1` |
| 02 | specify | `spec.md` (FR/AC/authorization/data volume/UI states) and `gap-analysis.md`; `lint` | — |
| 03 | clarify | resolve only material questions (≤ 5, with recommendations); `clarifications.md` | `gate G2` |
| 04 | plan | `plan.md` (constitution check, layer impact, component strategy, **MCP evidence**, render mode, slices); `test-scenarios.md` | `gate G3` |
| 05 | tasks | `tasks.md` (T-### per slice, FR/AC links, verification) | — |
| 06 | analyze | `analyze`; fix inconsistencies; add manual findings | `gate G4` |
| 07 | implement | per task: MCP loop → smallest change → tick task. Per slice: `gate G5 -Slice S-##`, `gate G6`, `phase implement -CompleteSlice S-##` | all slices done |
| 08 | review | answer checklists in `review.md`; `scan -ListManual`; reviewer role if available | `gate G7` |
| 09 | done | Definition of Done | `gate G8` |

Read only what the current phase needs: the workflow file `{{KIT}}/core/workflows/NN-*.md`, plus the files it lists. Always keep the constitution (`{{KIT}}/core/constitution/constitution.md`) and local amendments (`.speckit/radzen/local/`) in force.

Trivial changes (a label, a typo) may skip phases 02–06 when the user agrees; G5 and G6 still apply.

## MCP loop (every Radzen API need)

1. Name the need precisely (component + member + purpose).
2. Reuse evidence if it exists for the installed Radzen version.
3. Otherwise query MCP with the exact component name, data shape, interaction and version (`{{KIT}}/core/mcp/query-playbook.md`).
4. Record: `speckit-radzen evidence add -Component … -Members … -Question … -Query … -Source mcp -Summary …`.
5. Cross-check against project usage; code; let G5 compile-verify.
6. Unavailable MCP, quota or conflicts: `{{KIT}}/core/mcp/fallback-matrix.md`.

## Reporting format

When you finish a phase or slice, report:

- what changed (files) and why (FR/AC/T IDs);
- gate results, quoted: `G5 S-01: PASS (build ok, 0 new warnings, 12/12 tests)`;
- evidence used (MCP IDs) and any fallbacks;
- open questions or stop conditions, with the decision you need.

## References

- Constitution: `{{KIT}}/core/constitution/constitution.md`
- Workflows: `{{KIT}}/core/workflows/README.md`
- Gates: `{{KIT}}/core/gates/quality-gates.md`
- Anti-patterns: `{{KIT}}/core/antipatterns/index.md`
- Standards: `{{KIT}}/core/standards/README.md` · Patterns: `{{KIT}}/core/patterns/README.md`
- MCP: `{{KIT}}/core/mcp/mcp-workflow.md`
- Roles: `{{KIT}}/core/agents/roles/`
