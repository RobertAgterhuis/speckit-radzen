# Security Checklist (G7)

- [ ] Sensitive operations have trusted-layer authorization (P-07, AP-SEC-01/02) — enforcement point per operation
- [ ] UI visibility is not relied on as enforcement
- [ ] Only necessary data is requested/rendered (AP-SEC-08)
- [ ] No secrets, tokens or internal exception details exposed (AP-SEC-03/04/05/10)
- [ ] Existing security middleware/controls preserved (AP-SEC-06/09)
- [ ] Destructive behaviour explicitly understood (confirmation, soft/hard delete, audit)
- [ ] Forbidden behaviour handled intentionally
