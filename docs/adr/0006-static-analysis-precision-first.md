# ADR-0006: Static analysis is precision-first

- **Status:** Accepted (2026-09-15)

## Context

The scanner is regex/structure based (ADR-0001). Noisy rules cause gate fatigue: agents and developers learn to ignore or waive findings.

## Decision

- A rule is automated only when it can be written with a low false-positive rate, proven by negative fixtures.
- Anything that needs semantic understanding is catalogued with `detection: manual-review` and appears in the G7 review checklist instead.
- Findings can be waived inline with a mandatory reason: `@* speckit-radzen:ignore AP-XXX-00 reason="…" *@` (Razor) or `// speckit-radzen:ignore AP-XXX-00 reason="…"` (C#). A waiver without a reason is itself a finding.
- Severity: `blocker` fails G6, `major` fails G6 unless waived, `minor` is reported only.
