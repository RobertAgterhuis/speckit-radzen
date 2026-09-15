# Discovery: {{feature title}}

- **Feature:** {{NNN-name}}
- **Profile:** `.speckit/radzen/profile.md` (fingerprint `{{first 12 chars}}`)
- **Solution:** {{solution path}}

## Request

{{The user's request, verbatim or closely paraphrased.}}

## Repository summary

<!-- Only what matters for this feature. Link to profile.md for the rest. -->

| Aspect | Value | Confidence | Evidence |
|---|---|---|---|
| Hosting model / render mode of target area | {{…}} | {{proven/inferred/unknown}} | {{file:line}} |
| Radzen version / wiring | {{…}} | {{…}} | {{…}} |
| UI → backend interaction | {{…}} | {{…}} | {{…}} |
| Authorization style | {{…}} | {{…}} | {{…}} |
| Validation | {{…}} | {{…}} | {{…}} |
| Test stack for touched layers | {{…}} | {{…}} | {{…}} |

## Analogous feature

<!-- The closest existing feature; the style reference for this work. -->

- {{path/to/Page.razor}} — {{why it is analogous}}

## Feature dependency trace

```text
{{[UI page] → [client/service] → [contract] → [endpoint/app service] → [validation] → [authorization] → [persistence/external] }}
```

## Cross-cutting concerns

| Concern | Existing behaviour | Evidence |
|---|---|---|
| Error handling | {{…}} | {{…}} |
| Logging / correlation | {{…}} | {{…}} |
| Localization | {{…}} | {{…}} |
| Caching / resilience | {{…}} | {{…}} |
| Concurrency | {{…}} | {{…}} |

## Scope classification

| Area | Classification | Notes |
|---|---|---|
| {{path or project}} | {{READ-ONLY CONTEXT / LIKELY CHANGE / OUT OF SCOPE / UNKNOWN}} | {{…}} |

## Unknowns

### Blocking

<!-- Write "None." when there are none. G1 fails while this section lists items. -->

- {{…}}

### Non-blocking

- {{…}}

## Out-of-scope findings

<!-- Brownfield issues noticed but not part of this feature. -->

- {{…}}
