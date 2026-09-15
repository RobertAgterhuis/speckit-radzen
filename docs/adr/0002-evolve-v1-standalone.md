# ADR-0002: Evolve V1 in place as a standalone kit

- **Status:** Accepted (2026-09-15)

## Context

GitHub Spec Kit offers an extension model. V1 of Spec Kit Radzen is a standalone kit with its own phases and installer.

## Decision

V2 extends the existing V1 repository and content. It stays standalone: no dependency on the `specify` CLI and no Spec Kit extension package. V1 content (constitution principles, workflows, standards, patterns, templates, checklists) is preserved and expanded rather than replaced.

For familiarity, feature artifacts live in `specs/NNN-feature-name/`, a convention Spec Kit users already know.

## Consequences

- One lifecycle to maintain (our installer).
- Repositories that also use GitHub Spec Kit can host both; the phase commands are namespaced (`speckit-radzen.*`) and do not collide with `/speckit.*`.
- If `specs/` already contains Spec Kit features, numbering continues from the highest existing number.
