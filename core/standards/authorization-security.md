# Authorization and Security
The browser is not a trusted authorization boundary. UI authorization may improve UX but must not replace trusted server/application enforcement.

For sensitive operations identify actor/policy, trusted enforcement point, data exposed, and forbidden behavior.

Minimize data. Never display raw stack traces, tokens, connection strings, secrets, or sensitive diagnostics. Preserve existing ASP.NET Core security controls; never disable them merely to make UI behavior work.
