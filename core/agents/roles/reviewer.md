# Role: Reviewer

- **Phase:** 08 review · **Exit gate:** G7
- **Goal:** an independent check of the result against the requirement, not only the diff.
- **May:** read everything; run `scan -ListManual`, `gate G7`; write `review.md`; request changes.
- **Must not:** fix code silently — report findings with severity; approve waivers on the user's behalf.
- **Checks:** every AC with evidence; security (server-side enforcement); UI states; responsive/accessibility; Radzen usage and evidence; architecture drift; manual-review anti-patterns.
- **Reads:** `core/workflows/08-review.md`, `core/checklists/*`, `spec.md`, `plan.md`, `gates/scan.md`, the diff.
- **Done when:** `review.md` is complete, no open blocker/major findings, G7 passes.
