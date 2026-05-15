require "net/http"
require "uri"
require "json"

module NurseAndrea
  class HttpClient
    REJECTION_WARNING_THRESHOLD = 5
    REJECTION_STATUSES          = [ 401, 403, 422, 429 ].freeze

    @@consecutive_rejections = 0
    @@warned_for_error       = nil
    @@mutex                  = Mutex.new

    class << self
      def reset_rejection_state!
        @@mutex.synchronize do
          @@consecutive_rejections = 0
          @@warned_for_error       = nil
        end
      end
    end

    def initialize
      @config = NurseAndrea.config
    end

    def post(url, body)
      uri  = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl     = uri.scheme == "https"
      http.open_timeout = @config.timeout
      http.read_timeout = @config.timeout

      request = Net::HTTP::Post.new(uri.path)
      build_headers.each { |k, v| request[k] = v }
      request.body = body.to_json

      response = http.request(request)
      handle_response(response, uri)

      response.code.to_i.between?(200, 299)
    rescue => e
      warn "[NurseAndrea] HTTP error posting to #{url}: #{e.class}: #{e.message}" if @config.debug
      false
    end

    private

    def build_headers
      {
        "Content-Type"              => "application/json",
        "Authorization"             => "Bearer #{@config.org_token}",
        "X-NurseAndrea-Workspace"   => @config.workspace_slug.to_s,
        "X-NurseAndrea-Environment" => @config.environment.to_s,
        "X-NurseAndrea-SDK"         => "#{@config.sdk_language}/#{@config.sdk_version}",
        # Sprint C — replay-mitigation timestamp. Server validates the
        # value is within ±5 minutes when the header is present; SDKs
        # older than 1.2.0 don't send it and the server accepts
        # gracefully. See docs/sdk/payload-format.md §2 + SECURITY.md.
        "X-NurseAndrea-Timestamp"   => Time.now.to_i.to_s,
        "User-Agent"                => "nurse_andrea-ruby/#{NurseAndrea::VERSION}"
      }
    end

    def handle_response(response, uri)
      status = response.code.to_i

      if status.between?(200, 299)
        @@mutex.synchronize do
          @@consecutive_rejections = 0
          @@warned_for_error       = nil
        end
        return
      end

      if @config.debug
        warn "[NurseAndrea] HTTP #{status} from #{uri}: #{response.body.to_s[0..200]}"
      end

      return unless REJECTION_STATUSES.include?(status)

      @@mutex.synchronize do
        @@consecutive_rejections += 1
        if @@consecutive_rejections >= REJECTION_WARNING_THRESHOLD
          surface_rejection_warning(response, status)
        end
      end
    end

    def surface_rejection_warning(response, status)
      body  = JSON.parse(response.body) rescue {}
      error = body.is_a?(Hash) ? body["error"].to_s : ""
      return if @@warned_for_error == error

      @@warned_for_error = error
      message = body.is_a?(Hash) ? body["message"].to_s : ""

      $stderr.puts(
        "[NurseAndrea] Ingest rejected (#{REJECTION_WARNING_THRESHOLD}+ consecutive). " \
        "Status: #{status} Error: #{error.empty? ? '(unknown)' : error}. " \
        "#{guidance_for(error)}#{message.empty? ? '' : " Details: #{message}"}"
      )
    end

    def guidance_for(error)
      case error
      when "invalid_org_token"
        "Check NURSE_ANDREA_ORG_TOKEN."
      when "workspace_rejected"
        "Restore the workspace in the dashboard or change workspace_slug."
      when "workspace_limit_exceeded"
        "Org has reached its workspace limit. Reject unused workspaces or upgrade plan."
      when "auto_create_disabled"
        "Auto-create disabled. Create the workspace explicitly in the dashboard before ingesting."
      when "environment_not_accepted_by_this_install"
        "Environment '#{@config.environment}' not accepted by NurseAndrea at #{@config.host}. Check NURSE_ANDREA_HOST."
      when "invalid_workspace_slug"
        SlugValidator::HUMAN_READABLE_RULES
      when "similar_slug_exists"
        "A similar slug already exists in this org. Did you mean an existing one?"
      when "creation_rate_limit_exceeded", "rate_limited"
        "Workspace creation rate limit hit. Existing workspaces still ingesting normally."
      else
        ""
      end
    end
  end
end
