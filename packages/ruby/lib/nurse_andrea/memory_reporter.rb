module NurseAndrea
  # Utility for reading process RSS. Called by MetricsShipper during its
  # flush loop — no separate thread or timer.
  class MemoryReporter
    class << self
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
