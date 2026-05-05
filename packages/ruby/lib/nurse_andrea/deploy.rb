module NurseAndrea
  # Public: ship a deploy event to the NurseAndrea backend so the
  # dashboard can render it as a vertical marker on time-series charts
  # and as a chip in the recent-deploys strip.
  #
  # Fire-and-forget: any failure (no token, network error, non-2xx) is
  # logged in debug mode and swallowed so the host application never
  # crashes from a deploy notification.
  module Deploy
    DESCRIPTION_LIMIT = 500

    def self.call(version:, deployer: nil, environment: "production", description: nil)
      return false unless NurseAndrea.config.valid?
      return false if version.to_s.strip.empty?

      payload = {
        version:     version.to_s,
        deployer:    deployer,
        environment: environment,
        description: description.is_a?(String) ? description[0, DESCRIPTION_LIMIT] : description,
        deployed_at: Time.now.utc.iso8601
      }.compact

      HttpClient.new.post(NurseAndrea.config.deploy_url, payload)
    rescue => e
      NurseAndrea.debug("[NurseAndrea] deploy() error: #{e.class}: #{e.message}")
      false
    end
  end

  # Convenience top-level: NurseAndrea.deploy(version: "1.4.2")
  def self.deploy(**kwargs)
    Deploy.call(**kwargs)
  end
end
