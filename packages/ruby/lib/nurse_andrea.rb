require "nurse_andrea/version"
require "nurse_andrea/configuration"
require "nurse_andrea/http_client"
require "nurse_andrea/log_interceptor"
require "nurse_andrea/log_shipper"
require "nurse_andrea/metrics_middleware"
require "nurse_andrea/metrics_shipper"
require "nurse_andrea/backfill"
require "nurse_andrea/job_instrumentation"
require "nurse_andrea/queue_depth_reporter"

require "nurse_andrea/railtie" if defined?(Rails::Railtie)
require "nurse_andrea/engine"  if defined?(Rails::Engine)

module NurseAndrea
  class ConfigurationError < StandardError; end

  class << self
    def configure
      yield(config)
    end

    def config
      @config ||= Configuration.new
    end

    def reset_config!
      @config = nil
    end
  end
end
