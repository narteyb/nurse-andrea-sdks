module NurseAndrea
  class EnvironmentDetector
    SUPPORTED = %w[production staging development].freeze

    class << self
      def detect
        raw = ENV["RAILS_ENV"] || ENV["RACK_ENV"]
        return "production" if raw.nil? || raw.empty?

        return raw if SUPPORTED.include?(raw)

        warn_unsupported(raw)
        "production"
      end

      def reset_warning!
        @warned = false
      end

      private

      def warn_unsupported(value)
        return if @warned

        @warned = true
        $stderr.puts(
          "[NurseAndrea] Detected environment '#{value}' is not in the " \
          "supported set #{SUPPORTED.inspect}. Falling back to 'production'."
        )
      end
    end
  end
end
