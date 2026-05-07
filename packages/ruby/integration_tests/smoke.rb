#!/usr/bin/env ruby
# Smoke test for the NurseAndrea Ruby SDK 1.0 against a running NA instance.
#
# Usage:
#   LOCAL_ORG_TOKEN=org_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx \
#     ruby integration_tests/smoke.rb
#
# Optional:
#   LOCAL_NA_HOST=http://localhost:4500   (default)
#   LOCAL_WORKSPACE_SLUG=smoke-test-ruby  (default)
#
# Exits 0 on success, non-zero on failure. Prints what to check next.

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "nurse_andrea"

ORG_TOKEN = ENV.fetch("LOCAL_ORG_TOKEN") do
  abort("LOCAL_ORG_TOKEN is required. Get it from `bin/rails db:seed` output.")
end
HOST = ENV.fetch("LOCAL_NA_HOST", "http://localhost:4500")
SLUG = ENV.fetch("LOCAL_WORKSPACE_SLUG", "smoke-test-ruby")

puts "[smoke] Configuring NurseAndrea SDK #{NurseAndrea::VERSION}"
puts "[smoke]   host:           #{HOST}"
puts "[smoke]   workspace_slug: #{SLUG}"
puts "[smoke]   environment:    development"

NurseAndrea.configure do |c|
  c.org_token      = ORG_TOKEN
  c.workspace_slug = SLUG
  c.environment    = "development"
  c.host           = HOST
  c.debug          = true
  c.batch_size     = 1
  c.flush_interval = 1
end

NurseAndrea.config.validate!

puts "[smoke] Posting 5 ingest payloads directly via HttpClient..."

require "securerandom"

success_count = 0
5.times do |i|
  ok = NurseAndrea::HttpClient.new.post(
    NurseAndrea.config.ingest_url,
    {
      services:     [ NurseAndrea.config.service_name ].compact,
      sdk_version:  NurseAndrea.config.sdk_version,
      sdk_language: NurseAndrea.config.sdk_language,
      logs: [
        {
          level:       "info",
          message:     "smoke test ##{i}",
          occurred_at: Time.now.utc.iso8601,
          source:      "smoke-test-ruby",
          batch_id:    SecureRandom.uuid,
          payload:     { iteration: i, ruby_version: RUBY_VERSION }
        }
      ]
    }
  )
  success_count += 1 if ok
  print(ok ? "." : "x")
end
puts

if success_count == 5
  puts "[smoke] OK — all 5 events accepted."
  puts "[smoke] Next: open #{HOST}/workspaces/pending and confirm '#{SLUG}' appears."
  exit 0
else
  warn "[smoke] FAIL — only #{success_count}/5 events accepted."
  exit 1
end
