require "rails/railtie"

module NurseAndrea
  class Railtie < Rails::Railtie
    # Runs after ALL initializers — including config/initializers/
    # This means NurseAndrea.configure works from config/initializers/ as expected
    initializer "nurse_andrea.wrap_logger", after: :load_config_initializers do
      if NurseAndrea.config.enabled? && NurseAndrea.config.valid?
        Rails.logger = NurseAndrea::LogInterceptor.new(Rails.logger)
        NurseAndrea::LogShipper.instance.start!
        NurseAndrea::MetricsShipper.instance.start!
        Rails.logger.info("[NurseAndrea] Logger interceptor installed " \
                          "(host: #{NurseAndrea.config.host}, " \
                          "service: #{NurseAndrea.config.service_name || 'auto'})")
      else
        warn "[NurseAndrea] Configuration incomplete at logger wrap time — " \
             "monitoring disabled. Ensure NurseAndrea.configure is called " \
             "in config/initializers/nurse_andrea.rb with a valid token."
      end
    end

    initializer "nurse_andrea.insert_middleware", after: :load_config_initializers do |app|
      if NurseAndrea.config.enabled? && NurseAndrea.config.valid?
        app.middleware.use NurseAndrea::MetricsMiddleware
        Rails.logger.info("[NurseAndrea] MetricsMiddleware inserted")
      else
        warn "[NurseAndrea] Skipping MetricsMiddleware — no token configured. " \
             "Ensure NurseAndrea.configure is called in config/initializers/nurse_andrea.rb"
      end
    end

    config.after_initialize do
      next unless NurseAndrea.config.enabled? && NurseAndrea.config.valid?
      NurseAndrea::Backfill.run_async!
    end

    at_exit do
      NurseAndrea::LogShipper.instance.flush! rescue nil
      NurseAndrea::MetricsShipper.instance.flush! rescue nil
    end
  end
end
