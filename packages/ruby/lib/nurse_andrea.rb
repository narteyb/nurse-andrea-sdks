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
require "nurse_andrea/job_instrumentation"
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

require "nurse_andrea/railtie" if defined?(Rails::Railtie)
require "nurse_andrea/engine"  if defined?(Rails::Engine)

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
