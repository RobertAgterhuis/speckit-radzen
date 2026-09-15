# Feature Specification: {{feature title}}

- **Feature:** {{NNN-name}}
- **Status:** Draft
- **Discovery:** `discovery.md`

## Problem

{{What problem does this solve, for whom, and why now?}}

## Actors

| Actor | Description | Authentication context |
|---|---|---|
| {{Role}} | {{…}} | {{e.g. Entra ID user with role X}} |

## User stories

<!-- Priority: P1 must, P2 should, P3 could. -->

- **US-001 (P1)** — As a {{actor}}, I want {{capability}} so that {{outcome}}.

## Functional requirements

- **FR-001** — {{Observable, testable behaviour}}. (US-001)

## Acceptance criteria

<!-- Every FR has at least one AC. Given/When/Then. Reference the FR in parentheses. -->

- **AC-001** (FR-001) — **Given** {{context}}, **when** {{action}}, **then** {{observable result}}.

## Authorization matrix

<!-- One row per operation. "Enforcement point" is the trusted server/application boundary (P-07). -->

| Operation | Actor | Allowed | Enforcement point | Evidence / gap |
|---|---|---|---|---|
| {{Read list}} | {{Role}} | {{yes/no}} | {{policy / endpoint}} | {{file:line or GAP}} |

## Data requirements

| Data | Source | Fields shown | Sensitive? |
|---|---|---|---|
| {{Customer}} | {{endpoint/service}} | {{…}} | {{yes/no}} |

## Data volume

<!-- P-10. State numbers, not adjectives. -->

- **Expected rows:** {{now}} → {{in two years}}
- **Bounded:** {{yes/no}}
- **Paging / filtering / sorting boundary:** {{server/client}} because {{reason}}

## UI states

<!-- P-08. Describe the behaviour or write "n/a – reason". -->

| Screen / region | Initial | Loading | Success | Empty | Validation failure | Operational failure | Forbidden | Read-only | Stale / concurrency |
|---|---|---|---|---|---|---|---|---|---|
| {{Screen}} | {{…}} | {{…}} | {{…}} | {{…}} | {{…}} | {{…}} | {{…}} | {{…}} | {{…}} |

## Non-functional requirements

- **NFR-001** (responsive) — {{…}}
- **NFR-002** (accessibility) — {{…}}
- **NFR-003** (performance) — {{…}}

## Existing capabilities

<!-- From discovery and gap analysis, with evidence. -->

- {{…}}

## Gaps

- {{…}} — see `gap-analysis.md`

## Non-goals

- {{…}}

## Constraints

- {{…}}

## Assumptions

- {{…}}

## Open questions

<!-- Mark inline in the text above as [NEEDS CLARIFICATION: Q-001 …]. List them here too. Write "None." when resolved. -->

- {{…}}
