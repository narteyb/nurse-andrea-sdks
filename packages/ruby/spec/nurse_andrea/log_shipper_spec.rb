require "spec_helper"

RSpec.describe NurseAndrea::LogShipper do
  let(:http_client) { instance_double(NurseAndrea::HttpClient, post: nil) }

  before do
    NurseAndrea.configure do |config|
      config.org_token      = "org_test_token"
      config.workspace_slug = "test-workspace"
      config.environment    = "development"
      config.host           = "http://localhost:4500"
      config.service_name   = "configured-service"
    end
    allow(NurseAndrea::HttpClient).to receive(:new).and_return(http_client)
  end

  describe "#flush! source resolution" do
    let(:shipper) { described_class.send(:new) }

    def shipped_logs
      payload = nil
      expect(http_client).to have_received(:post) do |_url, body|
        payload = body
      end
      payload[:logs]
    end

    it "honors a per-entry :source override" do
      shipper.send(:ship, [
        { level: "error", message: "db down", timestamp: "t",
          source: "nursingboard-cascade-db" }
      ])
      expect(shipped_logs.first[:source]).to eq("nursingboard-cascade-db")
    end

    it "falls back to the configured service_name when :source is omitted" do
      shipper.send(:ship, [ { level: "info", message: "hi", timestamp: "t" } ])
      expect(shipped_logs.first[:source]).to eq("configured-service")
    end

    it "uses the static default when neither :source nor service_name is set" do
      NurseAndrea.config.service_name = nil
      shipper.send(:ship, [ { level: "info", message: "hi", timestamp: "t" } ])
      expect(shipped_logs.first[:source]).to eq("nurse_andrea_gem")
    end

    it "preserves distinct per-entry sources within a single batch" do
      shipper.send(:ship, [
        { level: "error", message: "db",  timestamp: "t1", source: "nursingboard-cascade-db" },
        { level: "error", message: "web", timestamp: "t2", source: "nursingboard-cascade-web" },
        { level: "info",  message: "ok",  timestamp: "t3" }
      ])
      sources = shipped_logs.map { |l| l[:source] }
      expect(sources).to eq([
        "nursingboard-cascade-db",
        "nursingboard-cascade-web",
        "configured-service"
      ])
    end
  end
end
