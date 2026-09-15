# Phase 08 — Review

**Purpose:** review the result against the requirement, not only the diff.

## Entry — all slices passed G5 and G6

## Reads

`checklists/*.md`, `templates/review.md`, `antipatterns/index.md` (manual-review entries), `spec.md`, `plan.md`.

## Steps

1. Walk every AC and state how it is satisfied (file/test reference).
2. Complete the checklists and paste the result into `review.md`:
   - `checklists/security.md`
   - `checklists/ui-states.md`
   - `checklists/responsive-accessibility.md`
   - `checklists/radzen-usage.md`
   - `checklists/architecture.md`
3. Review every **manual-review** anti-pattern (`speckit-radzen scan -ListManual`) against the changed files.
4. Architecture drift: `speckit-radzen gate G7 -Feature NNN` compares package references and project files against the baseline and the plan's approved dependency changes.
5. Record findings with severity. Fix `blocker` and `major` findings, or record an approved waiver.
6. When a sub-agent/reviewer role is available (see `agents/roles/reviewer.md`), run the review in that role, separate from the implementer.

## Exit — G7

`review.md` complete, all checklist items answered with evidence or `n/a`, no open blocker/major findings, no unapproved drift.
