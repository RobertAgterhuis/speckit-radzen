# Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `requires PowerShell 7.4` | Windows PowerShell 5.1 or old pwsh | Install PowerShell 7.4+ and run with `pwsh` |
| Install: "files already exist and are not managed" | Your own files at adapter paths (or a V1 install) | Move them, or re-run with `-Force` (they are backed up in `.speckit/radzen/backup/`) |
| Install: "already installed" | A manifest exists | Use `-Update` |
| `verify-install`: `modified: …` | You edited a managed file | Move the change to `.speckit/radzen/local/`, or accept it; updates keep it and write `*.speckit-new` |
| `verify-install`: `unmerged update: …` | An update produced `*.speckit-new` | Merge the new content into the file and delete the `.speckit-new` file |
| G0 `profile-fresh` fails | Project files changed since `detect` | `detect` |
| G0 `solution-selected` fails | More than one solution | `detect -Solution path/to/App.sln` |
| G0 `profile-health` fails | Blocker health item (e.g. RDZ-H01) | Fix it in an approved slice, or add the ID to `gates.G0.allowHealth` with a reason in the plan |
| G0 `mcp-availability-recorded` fails | Not recorded | `state -Feature NNN -McpAvailability <value>` (available, unavailable, quota-exhausted) |
| G5 exit code 3 "No build baseline" | Baseline missing | `baseline` (on a clean tree, before changes) |
| G5 `new-warnings` fails on warnings you did not add | Baseline captured after changes, or a different SDK | Re-capture the baseline on the base commit with the same SDK |
| G5 times out | Large solution | Raise `gates.G5.timeoutMinutes`, set `testFilter` |
| G6 flags a legitimate case | Rule precision | Waive with a reason; report the case so the rule can be refined |
| G6 scans too much/too little | Base commit | Scope is "changed since the feature's base commit" (`state.json` → `baseRef`); commit unrelated work separately |
| G7 `dependency-drift` fails | New/changed package | List it under *Approved dependency changes* in `plan.md` (after approval) or revert |
| G8 `code-unchanged-since-gates` fails | Code changed after G5/G6/G7 | Re-run G5/G6 for the slices and G7 |
| `mcp-check`: `unauthorized` | Key wrong or licence expired | Check the key, licence (trial vs Pro/Team) |
| Agent says it has no Radzen tool | Client not configured or server not approved | See `docs/mcp-setup.md`; approve the project server in Claude Code |
| Headers with `${VAR}` not expanded | Client version limitation | Configure the server at user level (see mcp-setup) |
| Dialogs/notifications never show | Missing `<RadzenComponents />` or non-interactive host | See profile health RDZ-H02 / RND-H02 and `core/standards/radzen-setup.md` |
| Radzen events do nothing | Page is static SSR | Apply the interactive render mode (AP-RND-01) |
| Scripts blocked on Windows | Execution policy | `pwsh -ExecutionPolicy Bypass -File …` or `Unblock-File` on the extracted distribution |
