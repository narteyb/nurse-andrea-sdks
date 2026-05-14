#!/usr/bin/env ruby
# SDK Sprint A D3 — host-app fixture smoke test (GAP-03).
#
# Boots a minimal Rails::Application that depends on nurse_andrea via
# path:, runs the install-generator-equivalent setup (initializer +
# engine mount), and asserts:
#
#   1. Engine mounts at /nurse_andrea and serves /nurse_andrea/status
#      with a 200 JSON response.
#   2. MetricsMiddleware is present in the middleware stack.
#   3. Invalid configuration (missing org_token) triggers the
#      silent-degradation path: no exception is raised at boot, and
#      no middleware/logger interceptor is installed.
#
# Run: bundle exec ruby smoke.rb
# Exits 0 on success, non-zero on any assertion failure.

require "bundler/setup"
require "rails"
require "action_controller/railtie"
require "rack/test"
require "json"

ASSERTIONS = []

def assert(condition, message)
  ASSERTIONS << [ condition, message ]
  prefix = condition ? "✓" : "✗"
  warn "[smoke] #{prefix} #{message}"
end

# ── Phase 1: valid config — full activation expected ─────────────
ENV["NURSE_ANDREA_ORG_TOKEN"] = "org_smoketest_aaaaaaaaaaaaaaaaaaaaaa"

require "nurse_andrea"

NurseAndrea.configure do |c|
  c.org_token      = ENV["NURSE_ANDREA_ORG_TOKEN"]
  c.workspace_slug = "smoke-host"
  c.environment    = "development"
  c.host           = "http://localhost:0"   # unused — smoke never posts
  c.enabled        = true
  c.log_level      = :warn
end

class HostApp < Rails::Application
  config.load_defaults Rails::VERSION::STRING.to_f
  config.eager_load = false
  config.secret_key_base = "smoke" * 16
  config.logger = Logger.new(IO::NULL)
  config.hosts.clear

  routes.append do
    mount NurseAndrea::Engine => "/nurse_andrea"
  end
end

HostApp.initialize!

# Mount assertion
status_route = HostApp.routes.routes.find { |r| r.path.spec.to_s.include?("/nurse_andrea") }
assert !status_route.nil?, "NurseAndrea::Engine mounted under host app routes"

# Middleware assertion — MetricsMiddleware should be in the stack
# given valid config. Railtie installs it only when enabled? && valid?.
mw_names = HostApp.middleware.map { |m| m.klass.to_s }
assert mw_names.include?("NurseAndrea::MetricsMiddleware"),
       "NurseAndrea::MetricsMiddleware present in middleware stack (valid config)"

# Status endpoint assertion
class StatusSession
  include Rack::Test::Methods
  def app
    HostApp
  end
end

session = StatusSession.new
session.get "/nurse_andrea/status"
assert session.last_response.status == 200,
       "GET /nurse_andrea/status returns 200 (got #{session.last_response.status})"

content_type = session.last_response.headers["Content-Type"].to_s
assert content_type.include?("application/json"),
       "GET /nurse_andrea/status returns JSON (Content-Type: #{content_type})"

body = JSON.parse(session.last_response.body) rescue {}
assert body["status"] == "ok",
       "status endpoint body has status: ok (got #{body["status"].inspect})"
assert body["version"] == NurseAndrea::VERSION,
       "status endpoint body reports correct version (#{body["version"]} vs #{NurseAndrea::VERSION})"

# ── Phase 2: invalid config — silent degradation expected ────────
# Reset and verify that booting WITHOUT org_token does not raise and
# does not install the middleware. Exercised via Configuration#valid?
# rather than a second Rails boot (Rails::Application is a singleton).

NurseAndrea.reset_config!
NurseAndrea.configure do |c|
  c.workspace_slug = "smoke-host"
  c.environment    = "development"
  # No org_token — invalid.
end

assert !NurseAndrea.config.valid?,
       "Configuration without org_token is invalid (valid? == false)"

begin
  NurseAndrea.config.validate!
  assert false, "Configuration#validate! should raise without org_token"
rescue NurseAndrea::ConfigurationError => e
  assert e.message.include?("org_token"),
         "validate! raises ConfigurationError mentioning org_token"
end

# The Railtie wraps both gates in `if enabled? && valid?` and emits
# a `warn` to stderr on miss — it does NOT raise. The Configuration
# checks are the unit-level guarantee that the Railtie's predicate
# returns false; the warn-and-skip behavior is covered in railtie
# specs (D6).

# ── Summary ──────────────────────────────────────────────────────
failures = ASSERTIONS.count { |c, _| !c }
warn "[smoke] #{ASSERTIONS.size - failures} / #{ASSERTIONS.size} assertions passed"
exit(failures.zero? ? 0 : 1)
