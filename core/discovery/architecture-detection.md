# Architecture Detection

Describe what exists; do not prescribe what should exist.

Trace the requested feature through actual project references, namespaces, DI registrations, endpoint routing, services, persistence, HTTP clients, Razor dependencies, shared projects, and tests.

When multiple patterns exist, prefer:
1. closest analogous feature;
2. dominant pattern in the same project;
3. repository-wide convention;
4. a new pattern only when necessary and approved.

Do not repair brownfield architectural inconsistency as part of unrelated Radzen work. Record it separately unless it blocks the feature.
