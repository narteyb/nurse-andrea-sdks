module NurseAndrea
  class MemorySampler
    INTERVAL_SECONDS = 30

    def self.start
      return @thread if @thread&.alive?

      @thread = Thread.new do
        loop do
          sleep INTERVAL_SECONDS
          sample_and_enqueue
        rescue => e
          NurseAndrea.debug("[NurseAndrea] MemorySampler error: #{e.message}")
        end
      end
      @thread.abort_on_exception = false
      @thread.name = "NurseAndrea::MemorySampler"
      @thread
    end

    def self.stop
      @thread&.kill
      @thread = nil
    end

    # Returns RSS in bytes. Works on Linux (/proc) and macOS (ps).
    def self.rss_bytes
      if File.exist?("/proc/self/status")
        line = File.readlines("/proc/self/status").find { |l| l.start_with?("VmRSS:") }
        return nil unless line
        kb = line.split[1].to_i
        kb * 1024
      else
        kb = `ps -o rss= -p #{Process.pid}`.strip.to_i
        return nil if kb == 0
        kb * 1024
      end
    rescue
      nil
    end

    def self.sample_and_enqueue
      bytes = rss_bytes
      return unless bytes && bytes > 0

      MetricsShipper.instance.enqueue(
        name:      "process.memory.rss",
        value:     bytes,
        unit:      "bytes",
        tags:      { service: NurseAndrea.config.service_name },
        timestamp: Time.now.utc.iso8601(3)
      )
    end
  end
end
