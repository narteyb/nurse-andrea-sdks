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
      token = NurseAndrea.config.api_key.to_s
      return "not_configured" if token.empty?
      "#{token[0..7]}..."
    end
  end
end
