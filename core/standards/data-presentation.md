# Data Presentation
Before collection UI, determine expected cardinality, paging/filtering/sorting capability, server/client boundary, selection/editing needs, and mobile behavior.

Do not fetch all records by default for potentially unbounded data. Prefer repository-supported server paging/filtering/sorting, virtualization, and projection.

Use RadzenDataGrid when structured tabular comparison and grid behaviors are central; simple lists/cards do not require it.
