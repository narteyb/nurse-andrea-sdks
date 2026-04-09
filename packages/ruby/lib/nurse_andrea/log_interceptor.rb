require "delegate"
require "logger"

module NurseAndrea
  class LogInterceptor < SimpleDelegator
    SEV_LABEL = %w[DEBUG INFO WARN ERROR FATAL ANY].freeze

    def initialize(original_logger)
      super(original_logger)
      @min_level = NurseAndrea.config.min_log_level_int
    end

    %w[debug info warn error fatal].each do |level|
      define_method(level) do |progname = nil, &block|
        add(Logger.const_get(level.upcase), nil, progname, &block)
      end
    end

    def add(severity, message = nil, progname = nil, &block)
      result = super

      return result unless NurseAndrea.config.enabled? && NurseAndrea.config.valid?
      return result if severity.nil? || severity < @min_level

      msg = message.nil? ? (block ? block.call : progname) : message
      return result if msg.nil?

      level_str = SEV_LABEL[severity]&.downcase || "unknown"

      # Capture OpenTelemetry trace context if available
      trace_metadata = {}
      if defined?(OpenTelemetry) && OpenTelemetry.respond_to?(:tracer_provider)
        span_context = OpenTelemetry::Trace.current_span&.context
        if span_context&.valid?
          trace_metadata[:trace_id] = span_context.hex_trace_id
          trace_metadata[:span_id]  = span_context.hex_span_id
        end
      end

      NurseAndrea::LogShipper.instance.enqueue(
        level:     level_str,
        message:   msg.to_s.strip,
        timestamp: Time.now.utc.iso8601(3),
        metadata:  { progname: progname&.to_s }.merge(trace_metadata).compact
      )

      result
    end
  end
end
