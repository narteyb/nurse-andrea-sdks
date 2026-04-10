require "securerandom"

module NurseAndrea
  class TraceMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      return @app.call(env) unless NurseAndrea.config.enabled? && NurseAndrea.config.valid?
      return @app.call(env) if env["PATH_INFO"]&.start_with?("/nurse_andrea")

      trace_id = SecureRandom.hex(16)
      span_id  = SecureRandom.hex(8)
      start_ns = Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond)

      status, headers, body = @app.call(env)

      end_ns     = Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond)
      duration   = end_ns - start_ns
      is_error   = status.to_i >= 500
      operation  = "#{env['REQUEST_METHOD']} #{env['PATH_INFO']}"

      NurseAndrea::TraceExporter.instance.enqueue(
        trace_id:       trace_id,
        span_id:        span_id,
        parent_span_id: "",
        name:           operation,
        service_name:   NurseAndrea.config.service_name,
        kind:           2, # server
        start_time:     Time.at(0, start_ns, :nanosecond).utc,
        end_time:       Time.at(0, end_ns, :nanosecond).utc,
        duration_ns:    duration,
        status_code:    is_error ? 2 : 1,
        status_message: is_error ? "HTTP #{status}" : "",
        attributes:     [
          { key: "http.method",      value: { stringValue: env["REQUEST_METHOD"] } },
          { key: "http.url",         value: { stringValue: env["PATH_INFO"] } },
          { key: "http.status_code", value: { intValue: status.to_i } },
        ].to_json,
        events: "[]"
      )

      [status, headers, body]
    rescue => e
      $stderr.puts "[NurseAndrea] TraceMiddleware error: #{e.message}"
      raise
    end
  end
end
