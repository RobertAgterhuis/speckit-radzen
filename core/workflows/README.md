# Workflows

Spec Kit Radzen runs a feature through ten phases. Each phase has an **ENTRY** gate (what must be true before it starts) and an **EXIT** gate (what must be true before the next phase starts). Gates are defined in `../gates/quality-gates.md`.

```text
00 bootstrap ─G0─▶ 01 discover ─G1─▶ 02 specify ─▶ 03 clarify ─G2─▶ 04 plan ─G3─▶ 05 tasks ─▶ 06 analyze ─G4─▶
    ┌──────────────── per slice S-## ─────────────────┐
    │ 07 implement ─G5 (build/test)─G6 (scan)─▶ next  │ ─▶ 08 review ─G7─▶ 09 done ─G8─▶
    └─────────────────────────────────────────────────┘
```

| Phase | File | Reads (besides the constitution) | Writes | Exit gate |
|---|---|---|---|---|
| 00 bootstrap | `00-bootstrap.md` | `mcp/mcp-workflow.md` | `.speckit/radzen/profile.*`, `specs/NNN-*/state.json` | G0 |
| 01 discover | `01-discover.md` | `discovery/*`, `.speckit/radzen/profile.md` | `specs/NNN-*/discovery.md` | G1 |
| 02 specify | `02-specify.md` | `templates/spec.md`, `templates/gap-analysis.md`, relevant `patterns/*` | `spec.md`, `gap-analysis.md` | — |
| 03 clarify | `03-clarify.md` | `templates/clarifications.md` | `clarifications.md`, updated `spec.md` | G2 |
| 04 plan | `04-plan.md` | `templates/plan.md`, `standards/*`, `patterns/*`, `mcp/query-playbook.md` | `plan.md`, `mcp-evidence.json`, `test-scenarios.md` | G3 |
| 05 tasks | `05-tasks.md` | `templates/tasks.md` | `tasks.md` | — |
| 06 analyze | `06-analyze.md` | all feature artifacts | `analysis.md` | G4 |
| 07 implement | `07-implement.md` | `tasks.md`, `plan.md`, `mcp-evidence.md`, `antipatterns/index.md` | code, tests, evidence | G5 + G6 per slice |
| 08 review | `08-review.md` | `checklists/*`, `templates/review.md` | `review.md` | G7 |
| 09 done | `09-done.md` | `checklists/definition-of-done.md` | `gate-report.md` | G8 |

## Commands

All commands run through the entry script installed in the target repository:

```text
pwsh .speckit/radzen/tools/speckit-radzen.ps1 <command> [options]
```

In this documentation `speckit-radzen <command>` is shorthand for that line. Run `speckit-radzen help` for the full list.

## Rules that apply to every phase

- Read only the files the phase needs (the table above). Reading everything wastes context and dilutes the rules that matter.
- Record the phase transition with `speckit-radzen phase <name> -Feature NNN`. The command refuses to move forward when the required gate has not passed.
- Never report a gate as passed unless `specs/NNN-*/gates/G#.json` says so.
- A stop condition (constitution P-13) ends the phase. Report it with the evidence and the decision you need.
- Small, trivial requests (a label change, a typo) MAY skip phases 02–06 when the user agrees. G5 and G6 still apply to the change.
