# NurseAndrea Ruby SDK

The official Ruby gem for [NurseAndrea](https://nurseandrea.io) —
observability for Rails startups and any plain-Ruby service. Version
`1.3.0`.

As of 1.3.0 the gem loads cleanly in non-Rails Ruby processes
(Sinatra, plain Rack, background workers, CLI tools). See
[Non-Rails usage](#non-rails-usage) below.

## Installation

Add to your `Gemfile`:

```ruby
gem "nurse_andrea"
```

Then run:

```bash
bundle install
rails generate nurse_andrea:install
```

Set the required environment variable:

```bash
export NURSE_ANDREA_ORG_TOKEN="org_xxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

## What it does

- **Log shipping** — captures `Rails.logger` calls and ships them to
  the NurseAndrea dashboard.
- **Request metrics** — measures every HTTP request (duration,
  status, path) via Rack middleware.
- **Backfill** — ships the last 24h of your Rails log file on first
  startup.
- **Health endpoint** — mounts `/nurse_andrea/status` so the
  dashboard can verify the integration.

## Configuration

The `rails generate nurse_andrea:install` generator drops
`config/initializers/nurse_andrea.rb`:

```ruby
NurseAndrea.configure do |c|
  c.org_token      = ENV["NURSE_ANDREA_ORG_TOKEN"]
  c.workspace_slug = "your-app"
  c.environment    = ENV.fetch("RAILS_ENV", "production")
  c.host           = ENV.fetch("NURSE_ANDREA_HOST", "https://nurseandrea.io")
  c.enabled        = !Rails.env.test?
  c.log_level      = :warn
end
```

All three of `org_token`, `workspace_slug`, and `environment` are
required. Missing any of them silently disables the SDK and emits a
`stderr` warn — see [SECURITY.md](../../SECURITY.md) for the
misconfiguration contract.

## Non-Rails usage

The gem's core ships logs and metrics through plain Ruby — Rails is
only needed for the Rails-specific glue listed below. Sinatra,
plain-Rack, background workers, and non-web services can `require`
the gem directly:

```ruby
require "nurse_andrea"

NurseAndrea.configure do |c|
  c.org_token      = ENV["NURSE_ANDREA_ORG_TOKEN"]
  c.workspace_slug = "my-service"
  c.environment    = ENV.fetch("RACK_ENV", "production")
end

# Ship logs directly:
NurseAndrea::LogShipper.instance.enqueue(
  level:     "info",
  message:   "hello from sinatra",
  timestamp: Time.now.utc.iso8601(3)
)

# Or wrap the HTTP-metrics middleware in a Rack app:
use NurseAndrea::MetricsMiddleware
```

### What's available without Rails

- `NurseAndrea.configure`, `NurseAndrea.config`,
  `NurseAndrea.config.valid?`
- `NurseAndrea::LogShipper.instance` — direct log ingest API
- `NurseAndrea::MetricsShipper.instance` — direct metric ingest API
- `NurseAndrea::MetricsMiddleware` — Rack middleware for HTTP
  request duration / status / path
- `NurseAndrea.deploy(...)` — deploy markers
- Platform / managed-service / continuous discovery scanners

### What requires Rails

These features auto-wire when Rails is present and are inactive in
non-Rails processes. If you need any of them, install in a Rails
app instead:

- `NurseAndrea::Engine` mount at `/nurse_andrea/status` — the
  dashboard's health-check endpoint
- `NurseAndrea::Railtie` boot hooks — automatic
  `Rails.logger` wrapping, middleware installation,
  initializer-time validation, per-cause boot warnings
- `rails generate nurse_andrea:install` — drops the initializer
- `ActiveSupport::Notifications`-based instrumentation
  (`sql.active_record`, `cache_*`, `perform.active_job`,
  `deliver.action_mailer`)
- `NurseAndrea::JobInstrumentation` — `around_perform` hook for
  ActiveJob jobs
- Automatic backfill of the Rails log file on first boot

## Migration from 0.x

`api_key`, `token`, and `ingest_token` are no longer supported.
Setting any of them raises `NurseAndrea::MigrationError` at boot.
See [`docs/sdk/migration.md`](../../docs/sdk/migration.md).

## Version history

See [CHANGELOG.md](CHANGELOG.md).
