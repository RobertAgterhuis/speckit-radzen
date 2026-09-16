# Agent Behaviour Scenarios

Twenty scenarios (`SC-01` … `SC-20`) check that an AI agent following Spec Kit Radzen behaves as the constitution requires. Each file has the prompt, the expected (**Must**) and forbidden (**Must not**) behaviour, and a JSON **Harness** block with the fixture, setup steps and automated checks.

## Run a scenario

```powershell
# 1. Prepare a sandbox (fixture copy + git + kit install + setup) and print the prompt
./tests/scenarios/Invoke-Scenario.ps1 -Id SC-01 -Agent claude

# 2a. Manual: open the sandbox in your agent (VS Code/Copilot, Claude Code, Cursor, Codex), paste the prompt, save the transcript as TRANSCRIPT.md in the sandbox.
# 2b. Headless Claude Code (optional): the harness runs `claude -p` and saves the transcript.
./tests/scenarios/Invoke-Scenario.ps1 -Id SC-01 -Agent claude -Headless

# 3. Evaluate automated checks and record the rubric score
./tests/scenarios/Invoke-Scenario.ps1 -Id SC-01 -Agent claude -Evaluate -Sandbox <path> -Score 9 -Reviewer Robert
```

Scenarios that need the Radzen MCP expect `RADZEN_MCP_KEY` to be set and the client configured (`mcp/README.md`); SC-04 deliberately runs without it.

## Coverage

| Scenario | Principles / anti-patterns |
|---|---|
| SC-01 | P-03, P-10, P-12, AP-RDZ-02/03 |
| SC-02 | P-10, P-13, AP-DAT-02 |
| SC-03 | P-07, AP-SEC-01/02 |
| SC-04 | P-03, P-15, fallback matrix |
| SC-05 | P-03, P-04, AP-AGT-02 |
| SC-06 | P-16, AP-RND-01 |
| SC-07 | P-02, P-05 |
| SC-08 | P-13.7, clarify |
| SC-09 | AP-AGT-06 |
| SC-10 | P-12, AP-AGT-03 |
| SC-11 | P-12, AP-TST-01/03 |
| SC-12 | Studio guardrails, AP-ARC-05 |
| SC-13 | P-06, AP-FRM-01/02/05 |
| SC-14 | AP-RDZ-07 |
| SC-15 | P-09, AP-RSP-02 |
| SC-16 | P-13.8 |
| SC-17 | P-02, AP-ARC-01 |
| SC-18 | P-07, AP-SEC-05 |
| SC-19 | P-12, AP-AGT-04 |
| SC-20 | P-04, P-16, RDZ-H06 |
