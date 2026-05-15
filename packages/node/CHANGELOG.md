# Changelog

## [1.2.0] - 2026-05-14

### Added
- **`X-NurseAndrea-Timestamp` header on every outbound POST.** Set
  to `Math.floor(Date.now() / 1000).toString()` (unix-seconds
  integer) on logs, metrics, and deploy. Server-side window
  validation (±5 minutes) lands in the matching NurseAndrea Rails
  release; requests outside the window are rejected with HTTP 401
  `error: "timestamp_out_of_window"`.
  This is GAP-07 Phase 2 of the replay-mitigation work — see
  `SECURITY.md` and `docs/sdk/payload-format.md` §2.1 for the
  threat-model rationale and Phase 3 (HMAC) roadmap.
- Parity test extended to assert the timestamp header is present
  and within drift on logs / metrics / deploy.

### Notes
- **Backward compatibility.** Servers running the matching Rails
  release accept requests **without** the timestamp header (older
  SDKs), so upgrading the SDK without coordinating the server
  upgrade is safe. The accept-when-absent behavior goes away in
  Phase 3.

## [1.1.0] - 2026-05-14

### Breaking
- **`configure()` no longer throws `ConfigurationError` on missing /
  invalid fields.** Pre-1.1 a missing `orgToken`, `workspaceSlug`, or
  `environment` (or an unsupported environment value, or a malformed
  workspaceSlug) threw synchronously from `configure()`. As of 1.1
  the SDK silent-degrades to align with the cross-runtime
  misconfiguration contract documented in
  [`docs/sdk/payload-format.md`](../../docs/sdk/payload-format.md) §6:
  the validation failure is written to `stderr` as
  `[NurseAndrea] <reason> — monitoring disabled.`, `_config` is
  cleared, and `isEnabled()` returns `false`. No HTTP request reaches
  the wire while config is invalid.

  **What this means for host apps:**
  - Apps that relied on `configure()` throwing as a startup signal
    will now boot silently without monitoring. The only signal is
    the `stderr` warn line.
  - Verify SDK activation after deploy by hitting your engine's
    status endpoint or by checking `isEnabled()` programmatically.
  - `MigrationError` (legacy `apiKey` / `token` / `ingestToken`
    field names) still throws — that's a user-error guard, not a
    config-state signal. Behavior unchanged.

### Fixed (cross-runtime parity — wire spec at docs/sdk/payload-format.md)
- Metric entries on `/api/v1/metrics` now serialize the timestamp
  field as `occurred_at` (canonical) instead of `timestamp`. Ruby
  and Python were already using `occurred_at`; Node and Go diverged.
  Aligned to the 2-runtime existing convention.
- Deploy requests now attach the `X-NurseAndrea-SDK: node/<version>`
  header (Ruby was already attaching it via the shared HttpClient;
  Node was missing it on the deploy path specifically).

### Added
- Cross-runtime parity fixture test at `tests/parity.test.ts`
  exercising header / payload-structure / misconfig dimensions.

## [1.0.0] - 2026-05-06

### Breaking
- Replaced `token` / `apiKey` / `ingestToken` with three required fields:
  `orgToken`, `workspaceSlug`, `environment`. Passing any of the legacy
  field names to `configure()` throws `MigrationError` at boot. There is
  no compatibility shim.
- New required request headers: `Authorization: Bearer <orgToken>`,
  `X-NurseAndrea-Workspace: <slug>`, `X-NurseAndrea-Environment: <env>`.
- `environment` must be one of `production`, `staging`, `development`.
  Anything else is a `ConfigurationError`. `NODE_ENV=test` auto-detects to
  `production` with a one-time stderr warning.
- `workspaceSlug` is validated locally (lowercase a-z, 0-9, hyphens; must
  start with a letter; 1-64 chars). Reserved-word enforcement remains
  server-authoritative.
- `getConfig()` now throws if `configure()` hasn't run. Previously it
  silently returned a zero-token config.

### Added
- `isValidSlug` / `SLUG_RULES_HUMAN` exports.
- `detectEnvironment()` — auto-detection from `NODE_ENV` with one-time
  warning on unsupported values.
- `MigrationError` (descends from `ConfigurationError`).
- Structured rejection handling: after 5 consecutive `401`/`403`/`422`/
  `429` responses with the same error code, the SDK prints one stderr
  warning per process lifecycle with actionable guidance keyed off the
  server's `error` field.
- `X-NurseAndrea-SDK: node/<version>` identity header on every request.

### Migration
- See https://docs.nurseandrea.io/sdk/migration. Short version: replace
  the single `token:` line with `orgToken:`, `workspaceSlug:`,
  `environment:`. Pull `orgToken` from the org settings page; pick a slug
  for each app/service.
