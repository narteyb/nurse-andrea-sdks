## [0.1.7] - 2026-04-06

### Added
- `RAILWAY_SERVICE_NAME` is now the first candidate for auto-detecting
  `service_name`. Priority: RAILWAY_SERVICE_NAME → NURSE_ANDREA_SERVICE_NAME → Rails app name.

### Fixed
- `default_service_name` uses `.presence` on all ENV candidates to treat
  empty strings as absent.

## [0.1.6] - 2026-04-06

### Fixed
- `MetricsMiddleware` now inserted using `after: :load_config_initializers`,
  matching `wrap_logger`. Consumer apps no longer need `config.before_initialize`.

## [0.1.5] - 2026-04-06

### Fixed
- Added `require 'delegate'` for Ruby 4.0 compatibility. `SimpleDelegator`
  is no longer auto-loaded in Ruby 4.0.

## [0.1.4] - 2026-04-06

### Added
- `sdk_version` and `sdk_language` included in all outbound payloads
  (log batches, metric batches). Dashboard can display SDK version and
  surface update nudges.

## [0.1.3] - 2026-04-06

### Fixed
- Railtie `wrap_logger` now runs after `config/initializers/` using
  `after: :load_config_initializers`. Standard Rails initializer placement
  now works correctly.
- MetricsMiddleware insertion deferred to after initialization.
- Silent no-op replaced with clear STDERR warning when token is missing at boot.

### Added
- `service_name` configuration attribute — auto-detected from Rails app name,
  overridable via `NURSE_ANDREA_SERVICE_NAME` env var or `c.service_name =`.
- `service_name` included in all log and metric payloads.
- `NurseAndrea::ConfigurationError` for explicit validation failures.
- Install generator adds `.nurse_andrea_backfill_done` to `.gitignore`.

## [0.1.2] - 2026-04-05

### Added
- `NurseAndrea::Configuration#host` — configurable base URL for all SDK endpoints. Defaults to `https://nurseandrea.io`.
- All ingest, metrics, traces, and handshake URLs are now derived from `host`. Nothing is hardcoded.
- `token` / `token=` aliases for `api_key` / `api_key=`

### Migration
Add `c.host = ENV.fetch("NURSE_ANDREA_HOST", "https://nurseandrea.io")` to your initializer.

## [0.1.1] - 2026-04-05

### Changed
- LogInterceptor now captures OpenTelemetry trace_id and span_id in log metadata when an OTel span is active

## [0.1.0] - 2026-04-03

### Added
- Initial release
- Log shipping via background thread (thread-safe queue, configurable batch size and flush interval)
- Request metrics via Rack middleware (duration, status, normalized path)
- Log backfill on first connection (configurable hours, JSON and plaintext log formats)
- Handshake/status endpoint at `/nurse_andrea/status`
- Rails install generator (`rails generate nurse_andrea:install`)
- Zero runtime dependencies beyond Ruby stdlib
