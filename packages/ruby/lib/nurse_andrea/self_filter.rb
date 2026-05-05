# Suppresses discovery emission when the SDK is loaded inside
# NurseAndrea itself. Both the InstrumentationSubscriber (hook-based)
# and the ManagedServiceScanner (env-based) must consult this filter
# before adding to NurseAndrea.component_discoveries — otherwise the
# platform's own infrastructure shows up as proposed components on
# every workspace dashboard.

module NurseAndrea
  module SelfFilter
    SELF_INDICATORS = %w[nurseandrea nurse-andrea nurse_andrea].freeze

    class << self
      def platform_self?
        return @platform_self if defined?(@platform_self)
        @platform_self = compute_platform_self
      end

      def reset!
        remove_instance_variable(:@platform_self) if defined?(@platform_self)
      end

      def host_matches?(*candidates)
        candidates.compact.map(&:to_s).map(&:downcase).any? do |s|
          SELF_INDICATORS.any? { |i| s.include?(i) }
        end
      end

      private

      def compute_platform_self
        return false unless defined?(Rails) && Rails.application
        app_name = Rails.application.class.module_parent_name.to_s.downcase
        SELF_INDICATORS.any? { |i| app_name.include?(i) }
      rescue
        false
      end
    end
  end
end
