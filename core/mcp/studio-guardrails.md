# Radzen Blazor Studio MCP Guardrails

Studio MCP can change a project directly (scaffold pages, edit components, change themes, connect data sources). Those actions are powerful and broad; these rules keep them inside the kit's process.

1. **Only inside approved scope.** Use Studio actions only for tasks in `tasks.md`, and only on areas classified `LIKELY CHANGE`.
2. **Repository architecture wins.** If Studio scaffolds a data layer, service or page structure that differs from the repository's pattern (discovery → analogous feature), adapt the output to the repository pattern or do not use it. Generated data-access code that bypasses the repository's API/service layer is not acceptable (AP-ARC-05).
3. **No theme or global changes without a task.** Switching themes, changing colours, adding authentication or localization scaffolding are global changes; they need an explicit FR and plan entry.
4. **Review the diff.** After each Studio action, inspect the changed files (`git diff`) before continuing. Revert unexpected changes.
5. **Same gates.** Studio output passes G5, G6 and G7 like hand-written code. Record the Studio action in the task (`Implementation:`) so reviewers know which code was generated.
6. **Evidence still applies.** Radzen members that Studio generated are still subject to P-15: cite project usage (rank 2) after the build passes, or MCP evidence.
7. **No secrets.** Studio data-source connections must not write connection strings with credentials into tracked files (AP-SEC-04).
