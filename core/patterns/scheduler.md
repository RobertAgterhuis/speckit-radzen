# Pattern: Scheduler

**Use when:** Calendar-style planning of appointments or resources.

**Avoid when:** Simple date lists.

## Spec questions

- Views (day/week/month)?
- Load strategy per visible range?
- Create/move/resize allowed?
- Time zones?

## Implementation guidance

Follow the analogous feature first (P-02). Confirm every Radzen member through MCP (P-15).

- `RadzenScheduler` with `LoadData` for the visible range; server returns only that range.
- Handle slot/appointment selection through the repository dialogs.
- Store and display times with an explicit time-zone policy.

## MCP query recipes

- `RadzenScheduler TItem LoadData StartProperty EndProperty views SlotSelect AppointmentSelect`

## UI states

Loading range, empty range, conflict on save, forbidden edit.

## Responsive and accessibility

Prefer day/agenda views on small screens.

## Related anti-patterns

[AP-DAT-02](../antipatterns/dat.md#ap-dat-02), [AP-RDZ-07](../antipatterns/rdz.md#ap-rdz-07)

## Test scenarios

- Only the visible range is requested.
- Overlapping appointment is rejected when the spec forbids it.
