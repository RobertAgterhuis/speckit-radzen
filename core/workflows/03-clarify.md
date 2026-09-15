# Phase 03 — Clarify

**Purpose:** resolve only the ambiguities that materially change architecture, security, data contracts, user behaviour or scope.

## Entry

`spec.md` exists.

## Steps

1. Collect all `[NEEDS CLARIFICATION: Q-###]` markers from `spec.md`.
2. For each, decide whether the repository already answers it (existing convention, policy, pattern). If so, resolve it yourself and record the evidence.
3. Ask the user the remaining questions **in one batch**, at most five at a time, each with a recommended answer and the consequence of each option.
4. Record every question and decision in `clarifications.md` (`Q-###`, question, options, decision, decided by, impact on FR/AC/plan).
5. Update `spec.md`: replace each marker with the decision and reference `Q-###`.
6. Run `speckit-radzen gate G2 -Feature NNN`.

## Must clarify

- Authorization for sensitive operations when the repository does not already define it.
- Destructive semantics: hard vs soft delete, cascades, undo, audit.
- Bounded vs unbounded data when it changes the architecture (server paging needed?).
- Conflicting active repository patterns without clear precedence.
- Permission to make a backend or contract change outside the initial scope.
- Which solution/project applies in a multi-solution repository.

## Do not ask about

Naming, file placement, formatting, or anything the repository has already established.

## Exit — G2

No `[NEEDS CLARIFICATION]` markers remain; every FR has an AC; the authorization matrix, data-volume assumption and UI-state matrix are complete.
