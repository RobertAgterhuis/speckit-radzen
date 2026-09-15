# Pattern: File Upload

**Use when:** Users upload documents or images.

**Avoid when:** Uploading to endpoints without size/type validation and authorization.

## Spec questions

- Allowed types and maximum size?
- Where are files stored; who may read them?
- Progress and cancellation?
- Virus scanning / processing?

## Implementation guidance

Follow the analogous feature first (P-02). Confirm every Radzen member through MCP (P-15).

- `RadzenUpload` with the repository upload endpoint or a custom upload flow; set accepted types and size limits client-side and enforce them server-side.
- Authorize the upload endpoint; never trust the client file name.

## MCP query recipes

- `RadzenUpload Url Auto Accept MaxFileSize Progress Complete Error`
- `RadzenUpload custom upload without Url`

## UI states

Selecting, uploading (progress), success, rejected (type/size), failure.

## Responsive and accessibility

Large touch target; progress text readable.

## Related anti-patterns

[AP-SEC-02](../antipatterns/sec.md#ap-sec-02), [AP-SEC-03](../antipatterns/sec.md#ap-sec-03)

## Test scenarios

- Oversized file is rejected server-side.
- Unauthorized upload is rejected.
