require "singleton"
require "net/http"
require "json"
require "uri"

module NurseAndrea
  class TraceExporter
    include Singleton

    BATCH_SIZE     = 100
    FLUSH_INTERVAL = 5

    def initialize
      @queue  = []
      @mutex  = Mutex.new
      @thread = nil
    end

    def start!
      return if @thread&.alive?
      @thread = Thread.new { flush_loop }
      @thread.abort_on_exception = false
      @thread.name = "NurseAndrea::TraceExporter"
    end

    def enqueue(span)
      flush_now = @mutex.synchronize do
        @queue << span
        @queue.size >= BATCH_SIZE
      end
      flush! if flush_now
    end

    def flush!
      spans = @mutex.synchronize do
        return if @queue.empty?
        batch = @queue.dup
        @queue.clear
        batch
      end
      return if spans.nil? || spans.empty?
      ship(spans)
    end

    private

    def flush_loop
      loop do
        sleep FLUSH_INTERVAL
        flush!
      rescue => e
        $stderr.puts "[NurseAndrea::TraceExporter] #{e.message}"
      end
    end

    def ship(spans)
      # Wrap in OTLP JSON format
      payload = {
        resourceSpans: [{
          resource: {
            attributes: [
              { key: "service.name", value: { stringValue: NurseAndrea.config.service_name } }
            ]
          },
          scopeSpans: [{
            spans: spans.map { |s| otlp_span(s) }
          }]
        }]
      }

      uri = URI("#{NurseAndrea.config.host.to_s.chomp('/')}/api/v1/traces")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 5
      http.read_timeout = 5

      req = Net::HTTP::Post.new(uri.path)
      req["Content-Type"]  = "application/json"
      req["Authorization"] = "Bearer #{NurseAndrea.config.api_key}"
      req.body = payload.to_json

      response = http.request(req)
      unless response.code.to_i.between?(200, 299)
        $stderr.puts "[NurseAndrea::TraceExporter] POST #{uri} → #{response.code}"
      end
    rescue => e
      $stderr.puts "[NurseAndrea::TraceExporter] Ship error: #{e.message}"
    end

    def otlp_span(s)
      {
        traceId:            s[:trace_id],
        spanId:             s[:span_id],
        parentSpanId:       s[:parent_span_id],
        name:               s[:name],
        kind:               s[:kind],
        startTimeUnixNano:  (s[:start_time].to_f * 1_000_000_000).to_i.to_s,
        endTimeUnixNano:    (s[:end_time].to_f * 1_000_000_000).to_i.to_s,
        status:             { code: s[:status_code], message: s[:status_message] },
        attributes:         JSON.parse(s[:attributes]),
        events:             JSON.parse(s[:events])
      }
    end
  end
end
