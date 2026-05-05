require "spec_helper"

RSpec.describe NurseAndrea::SelfFilter do
  before { described_class.reset! }
  after  { described_class.reset! }

  describe ".host_matches?" do
    it "returns true for a value containing 'nurseandrea'" do
      expect(described_class.host_matches?("db.nurseandrea.io")).to be true
    end

    it "returns true for a value containing 'nurse_andrea'" do
      expect(described_class.host_matches?("nurse_andrea_development")).to be true
    end

    it "returns true for a value containing 'nurse-andrea'" do
      expect(described_class.host_matches?("redis://cache.nurse-andrea.internal:6379")).to be true
    end

    it "matches case-insensitively" do
      expect(described_class.host_matches?("DB.NURSEANDREA.IO")).to be true
    end

    it "returns false for a customer host" do
      expect(described_class.host_matches?("shop-db.aws.com", "shop_production")).to be false
    end

    it "returns false when all candidates are nil" do
      expect(described_class.host_matches?(nil, nil)).to be false
    end
  end

  describe ".platform_self?" do
    it "is true when Rails.application's parent module name matches" do
      rails_app = Class.new { def self.module_parent_name; "NurseAndrea"; end }
      rails     = double("Rails", application: double(class: rails_app))
      stub_const("Rails", rails)
      expect(described_class.platform_self?).to be true
    end

    it "is false for a customer Rails app" do
      rails_app = Class.new { def self.module_parent_name; "Shop"; end }
      rails     = double("Rails", application: double(class: rails_app))
      stub_const("Rails", rails)
      expect(described_class.platform_self?).to be false
    end

    it "is false when Rails is not defined" do
      hide_const("Rails") if defined?(Rails)
      expect(described_class.platform_self?).to be false
    end

    it "memoizes the result" do
      rails_app = Class.new { def self.module_parent_name; "NurseAndrea"; end }
      rails     = double("Rails", application: double(class: rails_app))
      stub_const("Rails", rails)
      expect(described_class.platform_self?).to be true
      hide_const("Rails")
      expect(described_class.platform_self?).to be true # cached
    end
  end
end
