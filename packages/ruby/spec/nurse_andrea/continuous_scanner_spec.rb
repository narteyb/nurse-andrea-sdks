require "spec_helper"

RSpec.describe NurseAndrea::ContinuousScanner do
  before do
    NurseAndrea.configure do |c|
      c.api_key = "test"
      c.host    = "http://localhost:4500"
    end
    described_class.stop!
    NurseAndrea.instance_variable_set(:@component_discoveries, [])
  end
  after { described_class.stop! }

  describe ".rescan_safely" do
    before do
      allow(NurseAndrea::SelfFilter).to receive(:platform_self?).and_return(false)
    end

    it "appends new discoveries to NurseAndrea.component_discoveries" do
      allow(NurseAndrea::ManagedServiceScanner).to receive(:scan).and_return([
        { type: "database", tech: "postgresql", provider: "aws", source: "env_detection" }
      ])
      described_class.rescan_safely
      expect(NurseAndrea.component_discoveries.length).to eq(1)
    end

    it "does not duplicate items already queued for the next flush" do
      existing = { type: "database", tech: "postgresql", provider: "aws", source: "env_detection" }
      NurseAndrea.component_discoveries << existing
      allow(NurseAndrea::ManagedServiceScanner).to receive(:scan).and_return([ existing ])
      described_class.rescan_safely
      expect(NurseAndrea.component_discoveries.length).to eq(1)
    end

    it "swallows scanner errors without raising" do
      allow(NurseAndrea::ManagedServiceScanner).to receive(:scan).and_raise("boom")
      expect { described_class.rescan_safely }.not_to raise_error
    end

    it "short-circuits when SelfFilter.platform_self? is true" do
      allow(NurseAndrea::SelfFilter).to receive(:platform_self?).and_return(true)
      expect(NurseAndrea::ManagedServiceScanner).not_to receive(:scan)
      described_class.rescan_safely
    end
  end

  describe ".start! and .stop!" do
    before do
      # Tighten the interval so the spec doesn't wait 5 minutes
      NurseAndrea.config.continuous_scan_interval = 0.05
      allow(NurseAndrea::SelfFilter).to receive(:platform_self?).and_return(false)
      allow(NurseAndrea::ManagedServiceScanner).to receive(:scan).and_return([])
    end

    it "spins up a named background thread on start!" do
      described_class.start!
      expect(described_class.running?).to be(true)
      expect(described_class.thread.name).to eq("nurse_andrea_continuous_scanner")
    end

    it "is idempotent — calling start! twice yields one thread" do
      described_class.start!
      first = described_class.thread
      described_class.start!
      expect(described_class.thread).to be(first)
    end

    it "stop! signals the thread to exit" do
      described_class.start!
      described_class.stop!
      expect(described_class.running?).to be(false)
    end

    it "does not start when configuration disables it" do
      NurseAndrea.config.disable_continuous_scan = true
      described_class.start!
      expect(described_class.running?).to be(false)
      NurseAndrea.config.disable_continuous_scan = false
    end

    it "actually invokes rescan_safely on the loop" do
      called = 0
      allow(described_class).to receive(:rescan_safely) { called += 1 }
      described_class.start!
      sleep 0.2
      described_class.stop!
      expect(called).to be > 0
    end
  end
end
