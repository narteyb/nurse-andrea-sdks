module NurseAndrea
  class Configuration
    attr_accessor :api_key, :host, :timeout, :log_level, :batch_size,
                  :flush_interval, :backfill_hours, :log_file_path,
                  :enabled, :debug, :service_name,
                  :sdk_version, :sdk_language

    LOG_LEVELS   = { debug: 0, info: 1, warn: 2, error: 3, fatal: 4 }.freeze
    DEFAULT_HOST = "https://nurseandrea.io"

    def initialize
      @host           = DEFAULT_HOST
      @api_key        = ENV["NURSE_ANDREA_INGEST_TOKEN"] || ENV["NURSE_ANDREA_TOKEN"]
      @timeout        = 5
      @log_level      = :debug
      @batch_size     = 100
      @flush_interval = 10
      @backfill_hours = 24
      @log_file_path  = nil
      @enabled        = true
      @debug          = false
      @service_name   = default_service_name
      @sdk_version    = NurseAndrea::VERSION
      @sdk_language   = "ruby"
    end

    alias_method :token,  :api_key
    alias_method :token=, :api_key=

    # All endpoint URLs derived from host
    def ingest_url    = "#{normalised_host}/api/v1/ingest"
    def metrics_url   = "#{normalised_host}/api/v1/metrics"
    def traces_url    = "#{normalised_host}/api/v1/traces"
    def handshake_url = "#{normalised_host}/api/v1/handshake"

    def enabled?
      @enabled
    end

    def min_log_level_int
      LOG_LEVELS.fetch(log_level.to_sym, 0)
    end

    def valid?
      !api_key.nil? && !api_key.to_s.strip.empty? && !host.nil?
    end

    def validate!
      unless valid?
        raise NurseAndrea::ConfigurationError,
          "[NurseAndrea] Configuration invalid. " \
          "Set NURSE_ANDREA_TOKEN and NURSE_ANDREA_HOST, then call " \
          "NurseAndrea.configure in config/initializers/nurse_andrea.rb"
      end
      self
    end

    private

    def normalised_host
      host.to_s.chomp("/")
    end

    def default_service_name
      ENV["RAILWAY_SERVICE_NAME"].then { |v| v&.strip.presence } ||
        ENV["NURSE_ANDREA_SERVICE_NAME"].then { |v| v&.strip.presence } ||
        rails_app_name
    end

    def rails_app_name
      if defined?(Rails) && Rails.respond_to?(:application) && Rails.application
        Rails.application.class.module_parent_name.underscore.dasherize
      end
    rescue
      nil
    end
  end
end
