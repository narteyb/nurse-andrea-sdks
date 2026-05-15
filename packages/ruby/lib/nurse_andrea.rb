# Sprint D D1 (GAP-09) — Rack-compatible core. The requires below
# divide into two layers:
#
#   1. Rack-compatible core (this block).
#      Loads in any Ruby process — Sinatra, plain Rack, background
#      worker, non-web service. Files in this layer reach into Rails
#      ONLY behind `defined?(Rails)` / `defined?(ActiveSupport)`
#      runtime guards inside methods, so requiring them in a non-
#      Rails context succeeds and the methods short-circuit at call
#      time.
#
#   2. Rails-only layer (the second block, guarded by Rails presence).
#      Files here unconditionally require `rails/*` or
#      `active_support/*` at the top of the file and therefore would
#      raise LoadError outside a Rails app.
#
# Audit findings that drove this layout — surprises documented for
# future maintainers:
#
#   * `log_interceptor`, `instrumentation_subscriber`, `query_subscriber`,
#     `backfill`, `queue_depth_reporter`, `self_filter` all *use*
#     Rails / ActiveSupport / SolidQueue / Sidekiq but only behind
#     `defined?` guards inside methods. They are Rack-compatible at
#     load time.
#   * `metrics_middleware` is plain Rack middleware — it touches the
#     env hash, never a Rails request object.
#   * `job_instrumentation` is the only file in the historical
#     unconditional list whose top-level requires (active_support/
#     concern) actually require Rails. It moves below.
#
# The install generator at `lib/generators/nurse_andrea/install` is
# auto-discovered by Rails when `rails generate` runs — it is never
# required from this file, so it stays where it is and no guard is
# needed here.
require "nurse_andrea/version"
require "nurse_andrea/errors"
require "nurse_andrea/slug_validator"
require "nurse_andrea/environment_detector"
require "nurse_andrea/configuration"
require "nurse_andrea/http_client"
require "nurse_andrea/log_interceptor"
require "nurse_andrea/log_shipper"
require "nurse_andrea/metrics_middleware"
require "nurse_andrea/metrics_shipper"
require "nurse_andrea/backfill"
require "nurse_andrea/queue_depth_reporter"
require "nurse_andrea/query_subscriber"
require "nurse_andrea/sanitizer"
require "nurse_andrea/platform_detector"
require "nurse_andrea/managed_service_scanner"
require "nurse_andrea/component_telemetry"
require "nurse_andrea/instrumentation_subscriber"
require "nurse_andrea/memory_sampler"
require "nurse_andrea/deploy"
require "nurse_andrea/self_filter"
require "nurse_andrea/continuous_scanner"
require "nurse_andrea/boot_diagnostics"

# Rails-only layer. Engine and Railtie pull in `rails/engine` /
# `rails/railtie` at the top of their files; job_instrumentation
# pulls in `active_support/concern`. Each guard checks for the
# corresponding base class so the require is skipped cleanly in
# non-Rails processes.
require "nurse_andrea/job_instrumentation" if defined?(ActiveSupport::Concern)
require "nurse_andrea/railtie"             if defined?(Rails::Railtie)
require "nurse_andrea/engine"              if defined?(Rails::Engine)

module NurseAndrea
  class << self
    def configure
      yield(config)
    end

    def config
      @config ||= Configuration.new
    end

    def reset_config!
      @config = nil
      @instrumentation_subscriber = nil
      @component_discoveries = nil
      @platform_context = nil
    end

    def instrumentation_subscriber
      @instrumentation_subscriber ||= InstrumentationSubscriber.new
    end

    def component_discoveries
      @component_discoveries ||= []
    end

    def platform_context
      @platform_context ||= PlatformDetector.context
    end

    def debug(message)
      return unless config.debug
      $stderr.puts(message)
    end
  end
end
