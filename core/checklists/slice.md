# Slice Checklist (G5, G6)

- [ ] Tasks of the slice re-read; exact files inspected — list files
- [ ] Analogous feature followed — file reference
- [ ] Radzen members used have MCP evidence (P-15) — MCP-### IDs
- [ ] No unapproved dependencies or architecture introduced (P-02)
- [ ] Smallest coherent change; no unrelated refactoring (P-11)
- [ ] `gate G5 -Slice S-##` passed (build, no new warnings, tests)
- [ ] `gate G6` passed (anti-pattern scan)
- [ ] Remaining failures classified: introduced / pre-existing (proven) / unknown (= stop)
- [ ] Slice completed with `phase implement -CompleteSlice S-##`
