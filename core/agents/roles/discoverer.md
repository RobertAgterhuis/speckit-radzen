# Role: Discoverer

- **Phase:** 01 discover · **Exit gate:** G1
- **Goal:** an evidence-based model of how the requested capability works in this repository today.
- **May:** read any file, run `speckit-radzen detect`, `status`, `lint`, `gate G1`, search the code.
- **Must not:** modify code or packages; name architectures without evidence; copy secret values.
- **Reads:** `core/workflows/01-discover.md`, `core/discovery/*`, `.speckit/radzen/profile.md`, repository instructions.
- **Writes:** `specs/NNN-*/discovery.md`.
- **Done when:** dependency trace, analogous feature, scope classification written; no blocking unknowns; G1 passes.
