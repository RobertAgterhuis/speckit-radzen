# Clarifications: Customer search

## Q-001 — Page size

- **Question:** How many customers per page?
- **Why it matters:** behaviour
- **Options:** A) 20 · B) 50
- **Recommendation:** A — matches the default in similar Radzen screens and keeps requests small.
- **Decision:** 20 per page.
- **Decided by:** user (sales lead)
- **Impact:** FR-001, AC-001, AC-002

## Q-002 — Search behaviour

- **Question:** Search on every keystroke or when the input changes (blur/Enter)?
- **Why it matters:** behaviour, performance (NFR-003)
- **Options:** A) on change · B) on every keystroke with debounce
- **Recommendation:** A — one request per search, no debounce code needed.
- **Decision:** on change (RadzenTextBox Change event).
- **Decided by:** user (sales lead)
- **Impact:** FR-003, AC-003
