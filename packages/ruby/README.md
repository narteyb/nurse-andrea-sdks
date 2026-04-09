# NurseAndrea Ruby SDK

The official Ruby gem for [NurseAndrea](https://nurseandrea.com) — observability for Rails startups.

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

Set your API key:

```bash
export NURSE_ANDREA_API_KEY="your_token_from_dashboard"
```

## What it does

- **Log shipping** — captures all `Rails.logger` calls and ships them to your NurseAndrea dashboard
- **Request metrics** — measures every HTTP request (duration, status code, path) via Rack middleware
- **Backfill** — ships the last 24h of your Rails log file on first startup
- **Health endpoint** — mounts `/nurse_andrea/status` so the dashboard can verify your connection

## Configuration

```ruby
NurseAndrea.configure do |config|
  config.api_key        = ENV["NURSE_ANDREA_API_KEY"]
  config.log_level      = :warn
  config.backfill_hours = 48
  config.enabled        = !Rails.env.test?
end
```

## Version history

See [CHANGELOG.md](CHANGELOG.md).
