require "net/http"
require "uri"
require "json"

module NurseAndrea
  class HttpClient
    def initialize
      @api_key = NurseAndrea.config.api_key
      @timeout = NurseAndrea.config.timeout
    end

    def post(url, body)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl      = uri.scheme == "https"
      http.open_timeout  = @timeout
      http.read_timeout  = @timeout

      request = Net::HTTP::Post.new(uri.path)
      request["Content-Type"]  = "application/json"
      request["Authorization"] = "Bearer #{@api_key}"
      request["User-Agent"]    = "nurse_andrea-ruby/#{NurseAndrea::VERSION}"
      request.body = body.to_json

      response = http.request(request)
      success = response.code.to_i.between?(200, 299)

      if NurseAndrea.config.debug && !success
        warn "[NurseAndrea] HTTP #{response.code} from #{uri}: #{response.body.to_s[0..200]}"
      end

      success
    rescue => e
      warn "[NurseAndrea] HTTP error posting to #{url}: #{e.class}: #{e.message}" if NurseAndrea.config.debug
      false
    end
  end
end
