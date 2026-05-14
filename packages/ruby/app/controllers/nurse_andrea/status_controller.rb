module NurseAndrea
  class StatusController < ActionController::API
    def show
      render json: {
        status:              "ok",
        version:             NurseAndrea::VERSION,
        rails_version:       defined?(Rails) ? Rails::VERSION::STRING : "n/a",
        ruby_version:        RUBY_VERSION,
        environment:         defined?(Rails) ? Rails.env : "unknown",
        integration_token:   masked_token,
        log_shipper_running: NurseAndrea::LogShipper.instance.running?,
        metrics_running:     NurseAndrea::MetricsShipper.instance.running?,
        timestamp:           Time.now.utc.iso8601,
        capabilities:        %w[logs metrics backfill handshake]
      }
    end

    private

    def masked_token
      # SDK Sprint A D3 (GAP-03 surfaced this) — pre-1.0 referenced
      # config.api_key, which now raises MigrationError. The 1.0
      # field is org_token; the status controller was missed during
      # the auth-contract rewrite. Host-app fixture smoke caught it.
      token = NurseAndrea.config.org_token.to_s
      return "not_configured" if token.empty?
      "#{token[0..7]}..."
    end
  end
end
