# Changelog

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
