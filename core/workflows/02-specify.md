# Phase 02 — Specify

**Purpose:** express the request as observable, testable behaviour and compare it with what the repository can already do.

## Entry — G1 passed

## Reads

`templates/spec.md`, `templates/gap-analysis.md`, the relevant files in `patterns/`, `specs/NNN-*/discovery.md`.

## Steps

1. Write user stories (`US-###`) with priority (P1 = must, P2 = should, P3 = could).
2. Derive functional requirements (`FR-###`). Each FR is observable and testable, and names its actor.
3. Write acceptance criteria (`AC-###`) in Given/When/Then form. **Every FR has at least one AC** and each AC references its FR.
4. Fill the **authorization matrix**: every operation × actor → allowed/denied, and the trusted enforcement point (existing policy or "gap").
5. Record the **data-volume assumption** (expected rows now and in two years, bounded or unbounded) and where paging/filtering/sorting happens.
6. Fill the **UI-state matrix** (P-08) for every screen/region.
7. Add non-functional requirements (`NFR-###`) for responsiveness, accessibility, performance, localization and security where relevant.
8. Record non-goals and assumptions. Separate facts (with evidence), assumptions and unknowns.
9. Mark every material ambiguity inline as `[NEEDS CLARIFICATION: Q-### …]`. Limit yourself to what changes architecture, security, data contracts, user behaviour or scope.
10. Complete `gap-analysis.md`: for each capability, is it required, does it exist (with evidence), what is the gap and in which layer.
11. Avoid implementation choices unless the repository forces them.
12. Run `speckit-radzen lint -Feature NNN -Artifact spec` and fix all errors.

## Exit

Spec and gap analysis exist and lint cleanly apart from open `[NEEDS CLARIFICATION]` markers, which phase 03 resolves.

## Anti-patterns to watch

AP-SEC-01 (UI visibility as authorization), AP-DAT-01 (unbounded data assumed small), AP-AGT-06 (asking trivial questions).
