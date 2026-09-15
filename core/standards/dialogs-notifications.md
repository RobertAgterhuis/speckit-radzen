# Dialogs and Notifications

## Dialogs

- Use dialogs for bounded, contextual interactions: confirmation, short create/edit, small selections, details. Not for long workflows or data exploration.
- Follow the repository's dialog convention (a wrapper service, standard `DialogOptions`, width presets).
- `OpenAsync` resolves to `null` when the dialog is dismissed. Pattern-match the result (AP-RDZ-07).
- `Confirm` returns a nullable boolean; treat anything other than `true` as "no".
- Close with a result from inside the dialog (`DialogService.Close(result)`).
- Give dialogs a title, keep keyboard/focus usable, and use responsive widths (AP-RSP-03).
- Dialogs require the component host in the layout with an interactive render mode (AP-RDZ-05/13).

## Notifications

- Use the repository's notification mechanism (a wrapper or `NotificationService`).
- Messages are safe and actionable: no exception messages, stack traces or identifiers that leak internals (AP-SEC-03). Include a correlation/trace id when the repository shows one.
- Notifications do not replace field validation.
- Choose severity deliberately (success, info, warning, error) and do not rely on colour alone (AP-A11Y-02).
