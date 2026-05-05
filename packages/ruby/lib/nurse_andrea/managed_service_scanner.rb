# PRIVACY: This file reads environment variable values to derive
# component metadata. Raw values never leave this process. Only
# derived metadata (type, tech, provider) is transmitted.
# See DATA_PRIVACY_POLICY.rb for the full policy.

module NurseAndrea
  module ManagedServiceScanner
    SCAN_MAP = {
      "DATABASE_URL"      => "database",
      "DATABASE_PRIVATE_URL" => "database",
      "REDIS_URL"         => "cache",
      "REDIS_PRIVATE_URL" => "cache",
      "RABBITMQ_URL"      => "queue",
      "CLOUDAMQP_URL"     => "queue",
      "MONGODB_URI"       => "database",
      "MONGO_URL"         => "database",
      "ELASTICSEARCH_URL" => "search",
      "KAFKA_BROKERS"     => "queue"
    }.freeze

    def self.scan
      # Skip env-based discovery entirely when the SDK is loaded inside
      # NurseAndrea itself — every URL we'd find belongs to the platform's
      # own infrastructure, not a customer component.
      return [] if NurseAndrea::SelfFilter.platform_self?

      discoveries = []

      SCAN_MAP.each do |var_name, component_type|
        url = ENV[var_name]
        next if url.nil? || url.strip.empty?
        next if NurseAndrea::SelfFilter.host_matches?(url)

        tech     = Sanitizer.extract_tech(url)
        provider = Sanitizer.extract_provider(url)

        raw = {
          type: component_type,
          tech: tech,
          provider: provider,
          source: "env_detection",
          variable_name: var_name
        }

        discoveries << Sanitizer.sanitize_discovery(raw)
      end

      discoveries.uniq { |d| [ d[:type], d[:tech], d[:provider] ] }
    end
  end
end
