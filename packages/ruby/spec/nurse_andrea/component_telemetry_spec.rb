require "spec_helper"

RSpec.describe NurseAndrea::ComponentTelemetry do
  subject(:telemetry) { described_class.new }

  before do
    NurseAndrea.configure do |c|
      c.org_token      = "org_test"
      c.workspace_slug = "test-workspace"
      c.environment    = "development"
    end
  end

  describe "#record_query" do
    it "increments count and duration" do
      telemetry.record_query(duration_ms: 5.0, table: "users")
      expect(telemetry.db[:query_count]).to eq(1)
      expect(telemetry.db[:total_duration_ms]).to eq(5.0)
    end

    it "tracks tables_accessed" do
      telemetry.record_query(duration_ms: 1.0, table: "users")
      telemetry.record_query(duration_ms: 2.0, table: "orders")
      expect(telemetry.db[:tables_accessed]).to include("users", "orders")
    end

    it "counts slow queries over 100ms" do
      telemetry.record_query(duration_ms: 150.0, table: "users")
      telemetry.record_query(duration_ms: 50.0, table: "users")
      expect(telemetry.db[:slow_query_count]).to eq(1)
    end
  end

  describe "#record_cache_read" do
    it "records hit" do
      telemetry.record_cache_read(hit: true)
      expect(telemetry.cache[:hit_count]).to eq(1)
      expect(telemetry.cache[:read_count]).to eq(1)
    end

    it "records miss" do
      telemetry.record_cache_read(hit: false)
      expect(telemetry.cache[:miss_count]).to eq(1)
      expect(telemetry.cache[:read_count]).to eq(1)
    end
  end

  describe "#record_job_complete" do
    it "tracks queue_names" do
      telemetry.record_job_complete(duration_ms: 100.0, queue_name: "default")
      expect(telemetry.jobs[:queue_names]).to include("default")
      expect(telemetry.jobs[:complete_count]).to eq(1)
    end
  end

  describe "#snapshot_and_reset!" do
    it "returns metrics and clears counters" do
      telemetry.record_query(duration_ms: 5.0, table: "users")
      telemetry.record_cache_read(hit: true)

      metrics = telemetry.snapshot_and_reset!
      expect(metrics.length).to eq(2)
      expect(metrics.find { |m| m[:type] == "database" }[:query_count]).to eq(1)
      expect(metrics.find { |m| m[:type] == "cache" }[:hit_count]).to eq(1)

      # Counters reset
      expect(telemetry.db[:query_count]).to eq(0)
      expect(telemetry.cache[:read_count]).to eq(0)
    end

    it "omits empty component types" do
      telemetry.record_query(duration_ms: 5.0)
      metrics = telemetry.snapshot_and_reset!
      expect(metrics.length).to eq(1)
      expect(metrics.first[:type]).to eq("database")
    end

    it "returns empty array when nothing recorded" do
      expect(telemetry.snapshot_and_reset!).to be_empty
    end
  end
end
