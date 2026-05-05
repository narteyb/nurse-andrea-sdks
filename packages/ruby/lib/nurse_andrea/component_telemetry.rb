# PRIVACY: This file aggregates framework hook data in-process.
# Only counts and durations are shipped — no query text, no keys,
# no raw data. See DATA_PRIVACY_POLICY.rb for the full policy.

require "set"

module NurseAndrea
  class ComponentTelemetry
    attr_reader :db, :cache, :jobs

    def initialize
      reset!
    end

    def record_query(duration_ms:, table: nil)
      @db[:query_count] += 1
      @db[:total_duration_ms] += duration_ms
      @db[:slow_query_count] += 1 if duration_ms > 100
      @db[:tables_accessed].add(table) if table.present?
    end

    def record_transaction(outcome:)
      @db[:transaction_count] += 1
      @db[:rollback_count] += 1 if outcome.to_s == "rollback"
    end

    def record_cache_read(hit:)
      @cache[:read_count] += 1
      hit ? @cache[:hit_count] += 1 : @cache[:miss_count] += 1
    end

    def record_cache_write
      @cache[:write_count] += 1
    end

    def record_cache_delete
      @cache[:delete_count] += 1
    end

    def record_job_complete(duration_ms:, queue_name: nil)
      @jobs[:complete_count] += 1
      @jobs[:total_duration_ms] += duration_ms
      @jobs[:queue_names].add(queue_name) if queue_name.present?
    end

    def record_job_enqueue(queue_name: nil)
      @jobs[:enqueue_count] += 1
      @jobs[:queue_names].add(queue_name) if queue_name.present?
    end

    def record_job_fail(queue_name: nil)
      @jobs[:fail_count] += 1
      @jobs[:queue_names].add(queue_name) if queue_name.present?
    end

    def snapshot_and_reset!
      metrics = []

      if @db[:query_count] > 0
        metrics << {
          type: "database", tech: @db[:tech],
          interval_ms: NurseAndrea.config.hook_interval_ms,
          query_count: @db[:query_count],
          slow_query_count: @db[:slow_query_count],
          total_duration_ms: @db[:total_duration_ms].round(2),
          tables_accessed: @db[:tables_accessed].to_a,
          transaction_count: @db[:transaction_count],
          rollback_count: @db[:rollback_count],
          error_count: 0
        }
      end

      if @cache[:read_count] > 0 || @cache[:write_count] > 0
        metrics << {
          type: "cache", tech: @cache[:tech],
          interval_ms: NurseAndrea.config.hook_interval_ms,
          read_count: @cache[:read_count], write_count: @cache[:write_count],
          hit_count: @cache[:hit_count], miss_count: @cache[:miss_count],
          delete_count: @cache[:delete_count],
          total_duration_ms: 0, error_count: 0
        }
      end

      if @jobs[:enqueue_count] > 0 || @jobs[:complete_count] > 0
        metrics << {
          type: "queue", tech: @jobs[:tech],
          interval_ms: NurseAndrea.config.hook_interval_ms,
          enqueue_count: @jobs[:enqueue_count],
          complete_count: @jobs[:complete_count],
          fail_count: @jobs[:fail_count],
          total_duration_ms: @jobs[:total_duration_ms].round(2),
          queue_names: @jobs[:queue_names].to_a,
          retry_count: 0, error_count: 0
        }
      end

      reset!
      metrics
    end

    private

    def reset!
      @db = { tech: "unknown", query_count: 0, slow_query_count: 0,
              total_duration_ms: 0.0, tables_accessed: Set.new,
              transaction_count: 0, rollback_count: 0 }
      @cache = { tech: "unknown", read_count: 0, write_count: 0,
                 hit_count: 0, miss_count: 0, delete_count: 0 }
      @jobs = { tech: "unknown", enqueue_count: 0, complete_count: 0,
                fail_count: 0, total_duration_ms: 0.0, queue_names: Set.new }
    end
  end
end
