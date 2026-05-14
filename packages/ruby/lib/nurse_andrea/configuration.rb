module NurseAndrea
  class Configuration
    SUPPORTED_ENVIRONMENTS = EnvironmentDetector::SUPPORTED

    MIGRATION_MESSAGE =
      "%<field>s is no longer supported in NurseAndrea SDK 1.0. " \
      "Migrate to org_token + workspace_slug + environment. " \
      "See https://docs.nurseandrea.io/sdk/migration"

    attr_accessor :org_token, :workspace_slug, :environment, :host,
                  :timeout, :log_level, :batch_size,
                  :flush_interval, :backfill_hours, :log_file_path,
                  :enabled, :debug, :service_name,
                  :sdk_version, :sdk_language,
                  :hooks_enabled, :hooks_database, :hooks_cache,
                  :hooks_jobs, :hooks_mailer, :hook_interval_ms,
                  :platform_detection, :service_discovery, :auto_connect,
                  :disable_continuous_scan, :continuous_scan_interval

    LOG_LEVELS   = { debug: 0, info: 1, warn: 2, error: 3, fatal: 4 }.freeze
    DEFAULT_HOST = "https://nurseandrea.io"

    def initialize
      @host           = DEFAULT_HOST
      @environment    = EnvironmentDetector.detect
      @timeout        = 5
      @log_level      = :debug
      @batch_size     = 100
      @flush_interval = 10
      @backfill_hours = 24
      @log_file_path  = nil
      @enabled            = true
      @debug              = false
      @service_name       = default_service_name
      @sdk_version        = NurseAndrea::VERSION
      @sdk_language       = "ruby"
      @hooks_enabled      = true
      @hooks_database     = true
      @hooks_cache        = true
      @hooks_jobs         = true
      @hooks_mailer       = true
      @hook_interval_ms   = 10_000
      @platform_detection = true
      @service_discovery  = true
      @auto_connect       = false
      @disable_continuous_scan  = false
      @continuous_scan_interval = 5 * 60
    end

    %i[api_key token ingest_token].each do |legacy|
      define_method(legacy) do
        raise MigrationError, format(MIGRATION_MESSAGE, field: legacy)
      end

      define_method("#{legacy}=") do |_|
        raise MigrationError, format(MIGRATION_MESSAGE, field: legacy)
      end
    end

    def ingest_url    = "#{normalised_host}/api/v1/ingest"
    def metrics_url   = "#{normalised_host}/api/v1/metrics"
    def traces_url    = "#{normalised_host}/api/v1/traces"
    def handshake_url = "#{normalised_host}/api/v1/handshake"
    def deploy_url    = "#{normalised_host}/api/v1/deploy"

    def enabled?
      @enabled
    end

    def min_log_level_int
      LOG_LEVELS.fetch(log_level.to_sym, 0)
    end

    def valid?
      validation_diagnostic.nil?
    end

    # Sprint A D6 (GAP-10) — returns nil when configuration is valid,
    # otherwise returns a symbol identifying the first failure mode.
    # The Railtie maps these symbols to operator-actionable stderr
    # messages so a missing-org_token miss tells the operator to
    # set the env var rather than emitting the generic
    # "Configuration incomplete at logger wrap time" line.
    #
    # Order matters: most-likely-missing field first. Operators
    # debugging from logs benefit from the first message being the
    # most common cause.
    def validation_diagnostic
      return :missing_org_token      if blank?(org_token)
      return :missing_workspace_slug if blank?(workspace_slug)
      return :missing_environment    if blank?(environment)
      return :invalid_environment    unless SUPPORTED_ENVIRONMENTS.include?(environment)
      return :invalid_workspace_slug unless SlugValidator.valid?(workspace_slug)
      return :missing_host           if host.nil?
      nil
    end

    def validate!
      raise_config_error("org_token is required")      if blank?(org_token)
      raise_config_error("workspace_slug is required") if blank?(workspace_slug)
      raise_config_error("environment is required")    if blank?(environment)

      unless SUPPORTED_ENVIRONMENTS.include?(environment)
        raise_config_error(
          "environment must be one of #{SUPPORTED_ENVIRONMENTS.join(', ')} " \
          "(got #{environment.inspect})"
        )
      end

      unless SlugValidator.valid?(workspace_slug)
        raise_config_error(
          "workspace_slug #{workspace_slug.inspect} is invalid. " \
          "#{SlugValidator::HUMAN_READABLE_RULES}"
        )
      end

      self
    end

    private

    def blank?(value)
      value.nil? || value.to_s.strip.empty?
    end

    def raise_config_error(message)
      raise ConfigurationError, "[NurseAndrea] #{message}"
    end

    def normalised_host
      host.to_s.chomp("/")
    end

    def default_service_name
      first_present_env("RAILWAY_SERVICE_NAME", "NURSE_ANDREA_SERVICE_NAME") || rails_app_name
    end

    def first_present_env(*names)
      names.each do |n|
        v = ENV[n].to_s.strip
        return v unless v.empty?
      end
      nil
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
