# Security

This document describes the security model of the NurseAndrea SDKs
(Ruby gem, Python package, npm package, Go module) — what they
transmit, what credentials they accept, what happens when those
credentials leak, what they do not do, and how to report a
vulnerability.

## Threat model

### What the SDKs transmit

Each SDK collects and forwards observability data from the host
application to the configured NurseAndrea endpoint:

- **Logs.** Lines written through the host app's standard logger
  (`Rails.logger` / Python logging / `console.log` / `log/slog`,
  depending on runtime). Captured at the configured `log_level`
  and above.
- **HTTP metrics.** Request duration, status code, path, method —
  emitted by the Rack / Express / Fastify / Django / FastAPI /
  Flask / NestJS / `http.HandlerFunc` middleware the SDK installs.
- **Process metrics.** Memory RSS sampled at the configured
  interval.
- **Component telemetry.** Detected infrastructure components
  inferred from the environment (`DATABASE_URL`, `REDIS_URL`, etc.)
  — provider name + tech category only. The actual URLs are not
  transmitted; see `lib/nurse_andrea/sanitizer.rb` for the
  Ruby implementation and equivalent files in other runtimes.
- **Deploy markers.** Optional one-off `deploy()` payloads tagged
  with the git SHA and environment at deploy time.

All traffic is HTTPS POST to the configured `host` (default
`https://nurseandrea.io`) carrying three headers:

```
Authorization: Bearer <org_token>
X-NurseAndrea-Workspace: <workspace_slug>
X-NurseAndrea-Environment: <production|staging|development>
```

### What the org token grants

The `org_token` (formerly `api_key` / `token` / `ingest_token` pre-
1.0; those names now raise `MigrationError` at boot) grants
permission to **ingest** data into a single NurseAndrea organization,
addressed by `workspace_slug`. The token does **not**:

- Grant read access to the NurseAndrea dashboard or its data.
- Create sessions, sign in users, or authenticate against the host
  application.
- Access user records or application data outside of what the host
  app itself logs.
- Make outbound requests to any endpoint other than the configured
  `host`.

### Consequences of token leakage

If an `org_token` is exfiltrated, an attacker with that token can:

- Inject fabricated log entries, metrics, and component-discovery
  payloads into the victim org's NurseAndrea workspace.
- Inflate metric counters and create noise that may obscure real
  signals.
- Auto-create workspaces by inventing new `workspace_slug` values
  (subject to the org's auto-create policy and rate limits — see
  `creation_rate_limit_exceeded` handling in `http_client.rb`).

The attacker cannot, with the token alone, read existing data,
modify dashboard configuration, or affect the host application's
own auth / session / user records.

**Remediation:** rotate the token in the NurseAndrea dashboard.
Old token immediately becomes invalid; new token issued. Update
the `NURSE_ANDREA_ORG_TOKEN` env var in the host app and redeploy.

### What the SDK does not do

- It does **not** intercept, validate, or create user sessions in
  the host app. The SDK is data-out-only.
- It does **not** read or transmit cookies, request bodies, or
  response bodies. Only request metadata (duration, status, path).
- It does **not** store credentials at rest. The `org_token` lives
  only in env vars and in-memory configuration.
- It does **not** perform any signed-request or HMAC verification.
  Authentication is plain bearer-token; transport security is
  delegated to TLS via the configured `host`.

## Misconfiguration behavior

If `org_token`, `workspace_slug`, or `environment` is missing,
blank, or otherwise invalid at boot, the SDK **disables itself
silently**:

- No exception is raised. The host application boots and operates
  normally.
- No middleware is installed. No logger is wrapped. No background
  shippers are started.
- A warning is emitted to `stderr` describing the specific failure
  mode (Sprint A D6 added per-cause messages — see
  `lib/nurse_andrea/railtie.rb`).

This degradation contract is intentional: a broken SDK initializer
must never take down the host application. Observability is
secondary to host availability.

**Operator verification.** After deploy, hit
`GET /<engine_mount>/status` (default `/nurse_andrea/status` for
the Ruby gem) and confirm the response reports
`{"status":"ok","log_shipper_running":true,"metrics_running":true}`.
A `not_configured` token or `running:false` shipper means the SDK
disabled itself; check stderr for the warn message.

## HTTP rejection handling

When the NurseAndrea endpoint rejects ingest (401, 403, 422, 429),
the SDK does **not** raise. It increments a per-process consecutive-
rejection counter and, after five in a row, emits a one-time warn
to stderr with an `error_code` and operator guidance pointer. The
mapping lives in `_guidance_for(error_code, ...)` in each runtime —
known codes include:

- `invalid_org_token` — token does not match any org.
- `workspace_rejected` — workspace marked rejected in the dashboard.
- `workspace_limit_exceeded` — org reached its plan's workspace cap.
- `auto_create_disabled` — org policy forbids auto-creation; slug
  must exist before first ingest.
- `environment_not_accepted_by_this_install` — the endpoint
  receiving traffic does not accept this `environment` value.
- `invalid_workspace_slug` — slug fails the validator regex.
- `similar_slug_exists` — typo guard, an existing slug is one
  character away.
- `creation_rate_limit_exceeded` / `rate_limited` — too many new
  workspaces too fast.

## Cross-runtime parity

Currently, the four runtimes share the same wire-level auth contract
(Bearer header + `X-NurseAndrea-Workspace` + `X-NurseAndrea-
Environment`) and the same set of `error_code` strings. There is no
HMAC-signed envelope, no per-request nonce, and no replay window.

A cross-runtime parity test (verifying that all four runtimes
produce byte-identical canonical payloads for a fixed
`(payload, secret, timestamp, nonce)` tuple) is **not present** and
is scoped for Sprint B if the SDKs evolve toward signed envelopes.

## Responsible disclosure

If you believe you have found a security vulnerability in any of
the NurseAndrea SDKs, please report it privately. **Do not file a
public GitHub issue or pull request describing the vulnerability.**

Preferred channel: GitHub Security Advisories on this repository,
which lets us coordinate a fix before public disclosure.

Email fallback: `[SECURITY_CONTACT]`. (Placeholder — replace with
the team's monitored security inbox before this SECURITY.md ships
to a public repository.)

We aim to acknowledge reports within three business days and
release a fix within thirty days of a confirmed vulnerability. We
do not currently run a paid bug bounty program; coordinated
disclosure with credit in the resulting advisory is the standing
offer.

## Supported versions

Security fixes ship to the latest minor release of each runtime's
1.x line. Pre-1.0 (0.x) is no longer supported — see
`docs/sdk/migration.md` for the upgrade path. Earlier 1.x patch
releases receive backports only for High / Critical severity.
