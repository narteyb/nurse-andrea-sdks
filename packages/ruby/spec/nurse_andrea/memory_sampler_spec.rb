require "spec_helper"

RSpec.describe NurseAndrea::MemorySampler do
  before do
    NurseAndrea.configure do |c|
      c.org_token      = "org_test"
      c.workspace_slug = "test-workspace"
      c.environment    = "development"
    end
  end
  after { described_class.stop }

  describe ".rss_bytes" do
    it "returns a positive integer" do
      result = described_class.rss_bytes
      expect(result).to be_a(Integer)
      expect(result).to be > 0
    end
  end

  describe ".sample_and_enqueue" do
    it "enqueues a process.memory.rss metric" do
      allow(described_class).to receive(:rss_bytes).and_return(104_857_600)
      expect(NurseAndrea::MetricsShipper.instance).to receive(:enqueue).with(
        hash_including(name: "process.memory.rss", value: 104_857_600)
      )
      described_class.sample_and_enqueue
    end

    it "does nothing if rss_bytes returns nil" do
      allow(described_class).to receive(:rss_bytes).and_return(nil)
      expect(NurseAndrea::MetricsShipper.instance).not_to receive(:enqueue)
      described_class.sample_and_enqueue
    end
  end

  describe ".start and .stop" do
    it "starts a background thread" do
      thread = described_class.start
      expect(thread).to be_alive
      described_class.stop
    end

    it "does not start a second thread if already running" do
      t1 = described_class.start
      t2 = described_class.start
      expect(t1).to eq(t2)
      described_class.stop
    end
  end
end
