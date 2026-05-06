require "singleton"
require "securerandom"

module NurseAndrea
  class LogShipper
    include Singleton

    MAX_QUEUE_SIZE = 10_000

    def initialize
      @queue  = []
      @mutex  = Mutex.new
      @thread = nil
    end

    def start!
      return if @thread&.alive?
      @thread = Thread.new { flush_loop }
      @thread.abort_on_exception = false
      @thread.name = "NurseAndrea::LogShipper"
    end

    def stop!
      @thread&.kill
      flush!
    end

    def running?
      @thread&.alive? || false
    end

    def enqueue(entry)
      flush_now = @mutex.synchronize do
        @queue.shift if @queue.size >= MAX_QUEUE_SIZE
        @queue << entry
        @queue.size >= NurseAndrea.config.batch_size
      end
      flush! if flush_now
    end

    def flush!
      entries = @mutex.synchronize do
        return if @queue.empty?
        batch = @queue.dup
        @queue.clear
        batch
      end
      return if entries.nil? || entries.empty?

      ship(entries)
    end

    private

    def flush_loop
      loop do
        sleep NurseAndrea.config.flush_interval
        flush!
      rescue => e
        warn "[NurseAndrea::LogShipper] Error in flush loop: #{e.message}" if NurseAndrea.config.debug
      end
    end

    def ship(entries)
      HttpClient.new.post(NurseAndrea.config.ingest_url, {
        services:     [ NurseAndrea.config.service_name ].compact,
        sdk_version:  NurseAndrea.config.sdk_version,
        sdk_language: NurseAndrea.config.sdk_language,
        logs: entries.map { |e|
          {
            level:       e[:level],
            message:     e[:message],
            occurred_at: e[:timestamp],
            # Per-entry source override (e.g. for cross-service cascade
            # detection from a single integration) takes precedence; fall
            # back to the configured service_name, then a static default.
            source:      e[:source] || NurseAndrea.config.service_name || "nurse_andrea_gem",
            batch_id:    SecureRandom.uuid,
            payload:     e[:metadata] || {}
          }
        }
      })
    end
  end
end
