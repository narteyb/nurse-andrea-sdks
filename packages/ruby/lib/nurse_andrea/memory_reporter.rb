module NurseAndrea
  class MemoryReporter
    INTERVAL = 30 # seconds

    class << self
      def start!
        return if @thread&.alive?
        @thread = Thread.new { loop { ship_now!; sleep INTERVAL } rescue retry }
        @thread.abort_on_exception = false
        @thread.name = "NurseAndrea::MemoryReporter"
      end

      def ship_now!
        return unless NurseAndrea.config.enabled? && NurseAndrea.config.valid?

        rss = rss_bytes
        return unless rss&.positive?

        NurseAndrea::MetricsShipper.instance.enqueue(
          name:      "process.memory.rss",
          value:     rss,
          unit:      "bytes",
          timestamp: Time.now.utc.iso8601(3),
          tags:      { service: NurseAndrea.config.service_name }
        )
      end

      def rss_bytes
        if File.exist?("/proc/self/status")
          line = File.readlines("/proc/self/status").find { |l| l.start_with?("VmRSS:") }
          line ? line.split[1].to_i * 1024 : nil
        else
          kb = `ps -o rss= -p #{Process.pid}`.strip.to_i
          kb > 0 ? kb * 1024 : nil
        end
      rescue
        nil
      end
    end
  end
end
