module NurseAndrea
  class MetricsMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      return @app.call(env) unless NurseAndrea.config.enabled? && NurseAndrea.config.valid?
      return @app.call(env) if env["PATH_INFO"]&.start_with?("/nurse_andrea")

      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      status, headers, body = @app.call(env)
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round(2)

      NurseAndrea::MetricsShipper.instance.enqueue(
        name:      "http.server.duration",
        value:     duration_ms,
        unit:      "ms",
        timestamp: Time.now.utc.iso8601(3),
        tags: {
          service:     NurseAndrea.config.service_name,
          http_method: env["REQUEST_METHOD"],
          http_status: status.to_s,
          http_path:   normalize_path(env["PATH_INFO"])
        }.compact
      )

      [ status, headers, body ]
    rescue => e
      warn "[NurseAndrea] Middleware error: #{e.message}" if NurseAndrea.config.debug
      raise
    end

    private

    def normalize_path(path)
      return "/" if path.nil? || path.empty?
      path.gsub(%r{/\d+(/|$)}, '/:id\1')
    end
  end
end
