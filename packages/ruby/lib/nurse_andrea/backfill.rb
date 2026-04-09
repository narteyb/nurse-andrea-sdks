require "securerandom"
require "json"

module NurseAndrea
  class Backfill
    BATCH_SIZE  = 500
    MARKER_FILE = ".nurse_andrea_backfill_done"

    def self.run_async!
      Thread.new { new.run }.tap do |t|
        t.abort_on_exception = false
        t.name = "NurseAndrea::Backfill"
      end
    end

    def run
      return unless should_run?

      log_file = resolve_log_file
      return unless log_file && File.exist?(log_file)

      entries = parse_log_file(log_file)
      ship_in_batches(entries)
      mark_complete!
    rescue => e
      warn "[NurseAndrea] Backfill error: #{e.message}" if NurseAndrea.config.debug
    end

    private

    def should_run?
      return false unless NurseAndrea.config.enabled? && NurseAndrea.config.valid?
      !File.exist?(marker_path)
    end

    def resolve_log_file
      return NurseAndrea.config.log_file_path if NurseAndrea.config.log_file_path
      if defined?(Rails)
        Rails.root.join("log", "#{Rails.env}.log").to_s
      end
    end

    def parse_log_file(path)
      cutoff = Time.now.utc - (NurseAndrea.config.backfill_hours * 3600)
      entries = []

      File.foreach(path) do |line|
        line = line.strip
        next if line.empty?

        entry = parse_line(line)
        begin
          next if entry[:timestamp] && Time.parse(entry[:timestamp]) < cutoff
        rescue
          nil
        end

        entries << entry
      end

      entries
    rescue => e
      warn "[NurseAndrea] Log parse error: #{e.message}" if NurseAndrea.config.debug
      []
    end

    def parse_line(line)
      parsed = JSON.parse(line)
      {
        level:     parsed["level"] || parsed["severity"] || "info",
        message:   parsed["message"] || parsed["msg"] || line,
        timestamp: parsed["time"] || parsed["timestamp"] || Time.now.utc.iso8601(3),
        metadata:  { backfill: true }
      }
    rescue JSON::ParserError
      {
        level:     extract_level(line),
        message:   line,
        timestamp: Time.now.utc.iso8601(3),
        metadata:  { backfill: true }
      }
    end

    def extract_level(line)
      if line.match?(/\b(ERROR|FATAL)\b/i) then "error"
      elsif line.match?(/\bWARN\b/i)       then "warn"
      elsif line.match?(/\bDEBUG\b/i)      then "debug"
      else "info"
      end
    end

    def ship_in_batches(entries)
      client = HttpClient.new
      entries.each_slice(BATCH_SIZE) do |batch|
        client.post(NurseAndrea.config.ingest_url, {
          logs: batch.map { |e|
            { level: e[:level], message: e[:message], occurred_at: e[:timestamp], source: "backfill" }
          }
        })
        sleep 0.1
      end
    end

    def mark_complete!
      File.write(marker_path, Time.now.utc.iso8601)
    end

    def marker_path
      if defined?(Rails)
        Rails.root.join(MARKER_FILE).to_s
      else
        File.join(Dir.pwd, MARKER_FILE)
      end
    end
  end
end
