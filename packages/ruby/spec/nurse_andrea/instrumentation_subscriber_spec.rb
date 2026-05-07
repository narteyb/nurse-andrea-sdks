require "spec_helper"
require "active_support/notifications"

RSpec.describe NurseAndrea::InstrumentationSubscriber do
  subject(:subscriber) { described_class.new }

  before do
    NurseAndrea.configure do |c|
      c.org_token      = "org_test"
      c.workspace_slug = "test-workspace"
      c.environment    = "development"
    end
    NurseAndrea.instance_variable_set(:@component_discoveries, [])
  end

  describe "#subscribe_all" do
    it "subscribes to all events when ActiveSupport::Notifications available" do
      expect(ActiveSupport::Notifications).to receive(:monotonic_subscribe).exactly(8).times
      subscriber.subscribe_all
    end

    it "does not subscribe twice" do
      allow(ActiveSupport::Notifications).to receive(:monotonic_subscribe)
      subscriber.subscribe_all
      subscriber.subscribe_all
      expect(ActiveSupport::Notifications).to have_received(:monotonic_subscribe).exactly(8).times
    end
  end

  describe "SQL event handling" do
    it "records query in telemetry" do
      event = double("event",
        payload: { name: "User Load", sql: 'SELECT * FROM "users" WHERE id = 1', connection: nil },
        duration: 5.0)
      subscriber.send(:on_sql, event)
      expect(subscriber.telemetry.db[:query_count]).to eq(1)
    end

    it "skips SCHEMA queries" do
      event = double("event",
        payload: { name: "SCHEMA", sql: "SELECT version()", connection: nil },
        duration: 1.0)
      subscriber.send(:on_sql, event)
      expect(subscriber.telemetry.db[:query_count]).to eq(0)
    end

    it "skips ClickHouse adapter queries" do
      conn = double("connection", adapter_name: "Clickhouse")
      event = double("event",
        payload: { name: "Query", sql: "SELECT count() FROM metric_points", connection: conn },
        duration: 10.0)
      subscriber.send(:on_sql, event)
      expect(subscriber.telemetry.db[:query_count]).to eq(0)
      expect(subscriber.discovered_components).to be_empty
    end

    it "extracts table name from SQL" do
      expect(subscriber.send(:extract_table, 'SELECT * FROM "users"')).to eq("users")
      expect(subscriber.send(:extract_table, 'INSERT INTO "orders" VALUES')).to eq("orders")
      expect(subscriber.send(:extract_table, 'UPDATE "products" SET')).to eq("products")
    end
  end

  describe "cache event handling" do
    it "records hit in telemetry for RedisCacheStore" do
      event = double("event", payload: { store: "ActiveSupport::Cache::RedisCacheStore", hit: true })
      subscriber.send(:on_cache_read, event)
      expect(subscriber.telemetry.cache[:hit_count]).to eq(1)
    end

    it "registers discovery for RedisCacheStore" do
      event = double("event", payload: { store: "ActiveSupport::Cache::RedisCacheStore", hit: true })
      subscriber.send(:on_cache_read, event)
      expect(subscriber.discovered_components).to include("cache:redis")
    end

    it "does NOT register discovery for MemoryStore" do
      event = double("event", payload: { store: "ActiveSupport::Cache::MemoryStore", hit: true })
      subscriber.send(:on_cache_read, event)
      expect(subscriber.discovered_components).to be_empty
    end

    it "still records telemetry for MemoryStore" do
      event = double("event", payload: { store: "ActiveSupport::Cache::MemoryStore", hit: false })
      subscriber.send(:on_cache_read, event)
      expect(subscriber.telemetry.cache[:miss_count]).to eq(1)
    end

    it "does NOT register discovery for FileStore" do
      event = double("event", payload: { store: "ActiveSupport::Cache::FileStore", hit: true })
      subscriber.send(:on_cache_read, event)
      expect(subscriber.discovered_components).to be_empty
    end

    it "does NOT register discovery for NullStore" do
      event = double("event", payload: { store: "ActiveSupport::Cache::NullStore", hit: true })
      subscriber.send(:on_cache_read, event)
      expect(subscriber.discovered_components).to be_empty
    end
  end

  describe "store_to_tech" do
    it "returns redis for RedisCacheStore" do
      expect(subscriber.send(:store_to_tech, "ActiveSupport::Cache::RedisCacheStore")).to eq("redis")
    end

    it "returns nil for MemoryStore" do
      expect(subscriber.send(:store_to_tech, "ActiveSupport::Cache::MemoryStore")).to be_nil
    end

    it "returns nil for FileStore" do
      expect(subscriber.send(:store_to_tech, "ActiveSupport::Cache::FileStore")).to be_nil
    end

    it "returns nil for NullStore" do
      expect(subscriber.send(:store_to_tech, "ActiveSupport::Cache::NullStore")).to be_nil
    end
  end

  describe "discovery deduplication" do
    it "does not re-register duplicate discoveries" do
      subscriber.send(:register_discovery, "database", "postgresql")
      subscriber.send(:register_discovery, "database", "postgresql")
      expect(NurseAndrea.component_discoveries.length).to eq(1)
    end
  end

  describe "self-filter" do
    before { allow(NurseAndrea::SelfFilter).to receive(:platform_self?).and_return(false) }

    let(:conn_with) do
      lambda do |db_name: nil, host: nil|
        db_config = double("db_config", host: host)
        pool      = double("pool", db_config: db_config)
        double("connection",
               adapter_name:     "PostgreSQL",
               current_database: db_name,
               pool:             pool)
      end
    end

    describe "#self_referential?" do
      it "returns false for an external customer database" do
        conn = conn_with.call(db_name: "shop_production", host: "shop-db.aws.com")
        expect(subscriber.send(:self_referential?, conn)).to be false
      end

      it "returns true when the database name contains 'nurse_andrea'" do
        conn = conn_with.call(db_name: "nurse_andrea_development", host: "localhost")
        expect(subscriber.send(:self_referential?, conn)).to be true
      end

      it "returns true when the host contains 'nurseandrea'" do
        conn = conn_with.call(db_name: "platform_db", host: "db.nurseandrea.io")
        expect(subscriber.send(:self_referential?, conn)).to be true
      end

      it "returns true when SelfFilter says platform_self?" do
        allow(NurseAndrea::SelfFilter).to receive(:platform_self?).and_return(true)
        expect(subscriber.send(:self_referential?, nil)).to be true
      end

      it "returns false when not running inside NurseAndrea and no connection" do
        expect(subscriber.send(:self_referential?, nil)).to be false
      end
    end

    describe "#register_discovery" do
      it "does not emit for a self-referential connection" do
        conn = conn_with.call(db_name: "nurse_andrea_development")
        subscriber.send(:register_discovery, "database", "postgresql", connection: conn)
        expect(NurseAndrea.component_discoveries).to be_empty
      end

      it "emits for an external connection" do
        conn = conn_with.call(db_name: "shop_production", host: "rds.aws.com")
        subscriber.send(:register_discovery, "database", "postgresql", connection: conn)
        expect(NurseAndrea.component_discoveries.length).to eq(1)
      end

      it "skips cache discoveries when SelfFilter.platform_self? is true (no connection arg)" do
        allow(NurseAndrea::SelfFilter).to receive(:platform_self?).and_return(true)
        subscriber.send(:register_discovery, "cache", "redis")
        expect(NurseAndrea.component_discoveries).to be_empty
      end

      it "emits cache discoveries when running outside NurseAndrea" do
        subscriber.send(:register_discovery, "cache", "redis")
        expect(NurseAndrea.component_discoveries.length).to eq(1)
      end
    end
  end
end
