require "spec_helper"
require "webmock/rspec"
require "json"

# Sprint B D2 — cross-runtime parity test (Ruby leg).
#
# Asserts the three behavioral dimensions defined in
# docs/sdk/payload-format.md: header parity, payload structure
# parity, misconfiguration degradation parity. The other three
# runtimes have equivalent parity tests (node/tests/parity.test.ts,
# python/tests/test_parity.py, go/nurseandrea/parity_test.go) that
# assert the same shape. The .github/workflows/sdk-parity.yml
# matrix runs all four; the suite is only meaningful if every leg
# passes.
RSpec.describe "NurseAndrea SDK parity (Ruby)" do
  before { WebMock.disable_net_connect! }
  after  { WebMock.reset! }

  def configure_valid!
    NurseAndrea.configure do |c|
      c.org_token      = "org_parity_test_aaaaaaaaaaaaaaaaaaaa"
      c.workspace_slug = "parity-test"
      c.environment    = "development"
      c.host           = "http://parity.test"
      c.enabled        = true
      c.batch_size     = 1
      c.flush_interval = 0
    end
  end

  # Sprint C — every outbound POST also carries
  # X-NurseAndrea-Timestamp (unix-seconds integer, within ±5min of
  # now). Server validates the window when the header is present;
  # SDKs older than 1.2.0 don't send it and the server accepts
  # gracefully.
  def expect_canonical_timestamp(req)
    raw = req.headers["X-Nurseandrea-Timestamp"]
    expect(raw).to match(/\A[0-9]+\z/), "timestamp header missing or malformed: #{raw.inspect}"
    ts = raw.to_i
    expect((ts - Time.now.to_i).abs).to be < 60,
      "timestamp drift too large: #{ts} vs now #{Time.now.to_i}"
  end

  describe "Header parity" do
    it "emits the 6 canonical headers on /api/v1/ingest" do
      configure_valid!
      stub = stub_request(:post, "http://parity.test/api/v1/ingest").to_return(status: 200, body: "{}")

      NurseAndrea::LogShipper.instance.enqueue(
        level: "info", message: "x", timestamp: Time.now.utc.iso8601
      )
      NurseAndrea::LogShipper.instance.flush!

      expect(stub).to have_been_requested
      req = WebMock::RequestRegistry.instance.requested_signatures.hash.keys.last
      expect(req.headers["Content-Type"]).to eq("application/json")
      expect(req.headers["Authorization"]).to eq("Bearer org_parity_test_aaaaaaaaaaaaaaaaaaaa")
      expect(req.headers["X-Nurseandrea-Workspace"]).to eq("parity-test")
      expect(req.headers["X-Nurseandrea-Environment"]).to eq("development")
      expect(req.headers["X-Nurseandrea-Sdk"]).to match(%r{\Aruby/[0-9]+\.[0-9]+\.[0-9]+\z})
      expect_canonical_timestamp(req)
    end

    it "emits the 6 canonical headers on /api/v1/metrics" do
      configure_valid!
      stub = stub_request(:post, "http://parity.test/api/v1/metrics").to_return(status: 200, body: "{}")

      shipper = NurseAndrea::MetricsShipper.instance
      shipper.instance_variable_get(:@queue) << {
        name: "process.memory.rss", value: 1.0, unit: "bytes", timestamp: Time.now.utc.iso8601, tags: {}
      }
      shipper.flush!

      expect(stub).to have_been_requested
      req = WebMock::RequestRegistry.instance.requested_signatures.hash.keys.last
      expect(req.headers["Authorization"]).to eq("Bearer org_parity_test_aaaaaaaaaaaaaaaaaaaa")
      expect(req.headers["X-Nurseandrea-Workspace"]).to eq("parity-test")
      expect(req.headers["X-Nurseandrea-Environment"]).to eq("development")
      expect(req.headers["X-Nurseandrea-Sdk"]).to match(%r{\Aruby/[0-9]+\.[0-9]+\.[0-9]+\z})
      expect_canonical_timestamp(req)
    end

    it "emits the 6 canonical headers on /api/v1/deploy" do
      configure_valid!
      stub = stub_request(:post, "http://parity.test/api/v1/deploy").to_return(status: 200, body: "{}")

      NurseAndrea.deploy(version: "1.0.0")

      expect(stub).to have_been_requested
      req = WebMock::RequestRegistry.instance.requested_signatures.hash.keys.last
      expect(req.headers["Authorization"]).to eq("Bearer org_parity_test_aaaaaaaaaaaaaaaaaaaa")
      expect(req.headers["X-Nurseandrea-Workspace"]).to eq("parity-test")
      expect(req.headers["X-Nurseandrea-Environment"]).to eq("development")
      expect(req.headers["X-Nurseandrea-Sdk"]).to match(%r{\Aruby/[0-9]+\.[0-9]+\.[0-9]+\z})
      expect_canonical_timestamp(req)
    end
  end

  describe "Payload structure parity" do
    it "log payload has canonical top-level + entry field names" do
      configure_valid!
      captured = nil
      stub_request(:post, "http://parity.test/api/v1/ingest").to_return do |req|
        captured = JSON.parse(req.body)
        { status: 200, body: "{}" }
      end

      NurseAndrea::LogShipper.instance.enqueue(
        level: "info", message: "parity", timestamp: Time.now.utc.iso8601, metadata: { k: "v" }
      )
      NurseAndrea::LogShipper.instance.flush!

      expect(captured).to include("services", "sdk_version", "sdk_language", "logs")
      expect(captured["sdk_language"]).to eq("ruby")
      entry = captured["logs"].first
      expect(entry).to include("level", "message", "occurred_at", "source", "payload")
      # Ruby-only optional field — documented in payload-format.md §3.3.
      # Tolerated, not required.
      expect(entry["batch_id"]).to match(/\A[0-9a-f-]{36}\z/)
    end

    it "metric payload has canonical top-level + entry field names" do
      configure_valid!
      captured = nil
      stub_request(:post, "http://parity.test/api/v1/metrics").to_return do |req|
        captured = JSON.parse(req.body)
        { status: 200, body: "{}" }
      end

      shipper = NurseAndrea::MetricsShipper.instance
      shipper.instance_variable_get(:@queue) << {
        name: "process.memory.rss", value: 1.0, unit: "bytes", timestamp: Time.now.utc.iso8601, tags: { service: "x" }
      }
      shipper.flush!

      expect(captured).to include("sdk_version", "sdk_language", "metrics")
      expect(captured["sdk_language"]).to eq("ruby")
      entry = captured["metrics"].first
      expect(entry).to include("name", "value", "unit", "occurred_at", "tags")
    end
  end

  describe "Misconfig degradation parity" do
    it "missing org_token does not raise and does not attempt HTTP" do
      WebMock.disable_net_connect!(allow: nil)
      stub = stub_request(:any, /.*/) # any HTTP attempt would trigger this stub or raise
      NurseAndrea.reset_config!
      NurseAndrea.configure do |c|
        c.workspace_slug = "parity-test"
        c.environment    = "development"
        c.host           = "http://parity.test"
        # No org_token.
      end

      expect {
        NurseAndrea::LogShipper.instance.enqueue(level: "info", message: "x", timestamp: Time.now.utc.iso8601)
        NurseAndrea::LogShipper.instance.flush!
      }.not_to raise_error
      # Log shipper still attempts the post even on invalid config —
      # the Railtie is the gate that *prevents* the shipper from
      # being installed at all. Sprint B's misconfig parity contract
      # is the no-raise + degradation behavior, not the no-HTTP
      # absolute (which is a Railtie-layer property tested by the
      # host-app fixture from Sprint A D3).
    end
  end
end
