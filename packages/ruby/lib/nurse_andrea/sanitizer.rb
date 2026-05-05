# PRIVACY: This file enforces the data privacy policy. Only allowlisted
# fields pass through. See DATA_PRIVACY_POLICY.rb for the full policy.

require "uri"

module NurseAndrea
  module Sanitizer
    DISCOVERY_ALLOWLIST = %i[type tech provider source variable_name].freeze

    def self.sanitize_discovery(raw)
      raw.slice(*DISCOVERY_ALLOWLIST)
    end

    def self.extract_tech(url)
      scheme = URI.parse(url).scheme rescue nil
      case scheme
      when "postgres", "postgresql" then "postgresql"
      when "mysql", "mysql2"        then "mysql"
      when "redis", "rediss"        then "redis"
      when "amqp", "amqps"          then "rabbitmq"
      when "mongodb", "mongodb+srv" then "mongodb"
      else "unknown"
      end
    end

    def self.extract_provider(url)
      host = URI.parse(url).host rescue nil
      return "unknown" unless host

      case host
      when /\.railway\.internal$/       then "railway"
      when /\.render\.com$/             then "render"
      when /\.fly\.dev$/                then "fly"
      when /\.neon\.tech$/              then "neon"
      when /\.supabase\.co$/            then "supabase"
      when /\.upstash\.io$/             then "upstash"
      when /\.mongodb\.net$/            then "mongodb_atlas"
      when /\.herokuapp\.com$/          then "heroku"
      when /\.elephantsql\.com$/        then "elephantsql"
      when /\.aws\.clickhouse\.cloud$/  then "clickhouse_cloud"
      else "self_hosted"
      end
    end
  end
end
