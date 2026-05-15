# NurseAndrea Ruby SDK

The official Ruby gem for [NurseAndrea](https://nurseandrea.io) —
observability for Rails startups. Version `1.2.0`.

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

## Migration from 0.x

`api_key`, `token`, and `ingest_token` are no longer supported.
Setting any of them raises `NurseAndrea::MigrationError` at boot.
See [`docs/sdk/migration.md`](../../docs/sdk/migration.md).

## Version history

See [CHANGELOG.md](CHANGELOG.md).
