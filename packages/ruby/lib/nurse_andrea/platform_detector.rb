# PRIVACY: This file reads environment variable NAMES to detect
# the hosting platform. Only the platform name is transmitted.
# See DATA_PRIVACY_POLICY.rb for the full policy.

module NurseAndrea
  module PlatformDetector
    PLATFORMS = {
      railway:      -> { ENV.key?("RAILWAY_ENVIRONMENT") },
      render:       -> { ENV.key?("RENDER") },
      fly:          -> { ENV.key?("FLY_APP_NAME") },
      heroku:       -> { ENV.key?("DYNO") },
      digitalocean: -> { ENV.key?("DIGITALOCEAN_APP_PLATFORM_COMPONENT_NAME") },
      vercel:       -> { ENV.key?("VERCEL") }
    }.freeze

    def self.detect
      PLATFORMS.each { |name, check| return name.to_s if check.call }
      "unknown"
    end

    def self.context
      platform = detect
      ctx = { platform: platform }

      case platform
      when "railway"
        ctx[:region] = ENV["RAILWAY_REGION"] if ENV.key?("RAILWAY_REGION")
        ctx[:environment] = ENV["RAILWAY_ENVIRONMENT"] if ENV.key?("RAILWAY_ENVIRONMENT")
      when "render"
        ctx[:region] = ENV["RENDER_REGION"] if ENV.key?("RENDER_REGION")
      when "fly"
        ctx[:region] = ENV["FLY_REGION"] if ENV.key?("FLY_REGION")
      when "heroku"
        ctx[:dyno_type] = ENV["DYNO"]&.gsub(/\.\d+$/, "") if ENV.key?("DYNO")
      end

      ctx
    end
  end
end
