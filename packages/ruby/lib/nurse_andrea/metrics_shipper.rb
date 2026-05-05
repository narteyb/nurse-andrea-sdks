require "singleton"
require "securerandom"

module NurseAndrea
  class MetricsShipper
    include Singleton

    BATCH_SIZE     = 200
    FLUSH_INTERVAL = 15

    def initialize
      @queue  = []
      @mutex  = Mutex.new
      @thread = nil
    end

    def start!
      return if @thread&.alive?
      @thread = Thread.new { flush_loop }
      @thread.abort_on_exception = false
      @thread.name = "NurseAndrea::MetricsShipper"
    end

    def stop!
      @thread&.kill
      flush!
    end

    def running?
      @thread&.alive? || false
    end

    def enqueue(metric)
      flush_now = @mutex.synchronize do
        @queue << metric
        @queue.size >= BATCH_SIZE
      end
      flush! if flush_now
    end

    def flush!
      metrics = @mutex.synchronize do
        return if @queue.empty?
        batch = @queue.dup
        @queue.clear
        batch
      end
      return if metrics.nil? || metrics.empty?

      ship(metrics)
    end

    private

    def flush_loop
      loop do
        sleep FLUSH_INTERVAL
        flush!
      rescue => e
        warn "[NurseAndrea::MetricsShipper] #{e.message}" if NurseAndrea.config.debug
      end
    end

    def ship(metrics)
      payload = {
        sdk_version:  NurseAndrea.config.sdk_version,
        sdk_language: NurseAndrea.config.sdk_language,
        platform:     NurseAndrea.platform_context,
        metrics: metrics.map { |m|
          {
            name:        m[:name],
            value:       m[:value],
            unit:        m[:unit],
            tags:        m[:tags] || {},
            occurred_at: m[:timestamp]
          }
        }
      }

      # Include component telemetry if available
      component_metrics = NurseAndrea.instrumentation_subscriber
                                      .telemetry
                                      .snapshot_and_reset!
      payload[:component_metrics] = component_metrics if component_metrics.any?

      # Include component discoveries (flush once)
      if NurseAndrea.component_discoveries.any?
        payload[:component_discoveries] = NurseAndrea.component_discoveries.dup
        NurseAndrea.component_discoveries.clear
      end

      HttpClient.new.post(NurseAndrea.config.metrics_url, payload)
    end
  end
end
