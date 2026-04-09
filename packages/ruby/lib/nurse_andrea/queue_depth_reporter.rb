module NurseAndrea
  class QueueDepthReporter
    # Auto-detects Solid Queue or Sidekiq and reports queue depths.
    # Returns an array of metric hashes ready for MetricsShipper.

    def self.report!
      new.report!
    end

    def report!
      metrics = []
      now = Time.now.utc.iso8601(3)

      if solid_queue?
        metrics.concat(solid_queue_depths(now))
      elsif sidekiq?
        metrics.concat(sidekiq_depths(now))
      end

      metrics.each { |m| NurseAndrea::MetricsShipper.instance.enqueue(m) }
      metrics
    end

    private

    def solid_queue?
      defined?(SolidQueue::Job)
    end

    def sidekiq?
      defined?(Sidekiq::Queue)
    end

    def solid_queue_depths(now)
      queues = SolidQueue::Job
        .where(finished_at: nil)
        .group(:queue_name)
        .count

      queues.map do |queue_name, depth|
        {
          name:      "queue.depth",
          value:     depth,
          unit:      "count",
          timestamp: now,
          tags:      { queue_name: queue_name, backend: "solid_queue" }
        }
      end
    end

    def sidekiq_depths(now)
      Sidekiq::Queue.all.map do |queue|
        {
          name:      "queue.depth",
          value:     queue.size,
          unit:      "count",
          timestamp: now,
          tags:      { queue_name: queue.name, backend: "sidekiq" }
        }
      end
    end
  end
end
