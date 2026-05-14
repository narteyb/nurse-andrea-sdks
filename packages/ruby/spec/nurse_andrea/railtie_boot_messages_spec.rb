require "spec_helper"

# SDK Sprint A D6 (GAP-10) — per-failure-mode boot messages.
# Pre-Sprint-A the Railtie emitted a single generic warn regardless
# of which field was missing. These specs lock the per-cause message
# shape so future regressions surface immediately. Tests against
# NurseAndrea::BootDiagnostics directly so the suite doesn't have to
# boot Rails — the diagnostic map lives outside the Railtie precisely
# to keep this unit-level testable.
RSpec.describe NurseAndrea::BootDiagnostics do
  describe ".message_for" do
    let(:config) { NurseAndrea.config }

    context "when c.enabled = false" do
      it "returns the explicit-disabled message" do
        config.enabled = false
        message = described_class.message_for(config)
        expect(message).to eq("[NurseAndrea] monitoring is disabled (c.enabled = false).")
      end
    end

    context "when org_token is missing" do
      it "returns the missing-org_token message naming the env var" do
        config.workspace_slug = "smoke-app"
        config.environment    = "development"
        # org_token unset
        message = described_class.message_for(config)
        expect(message).to include("org_token is not set")
        expect(message).to include("NURSE_ANDREA_ORG_TOKEN")
        expect(message).to include("monitoring disabled")
      end
    end

    context "when workspace_slug is missing" do
      it "returns the missing-workspace_slug message naming the setter" do
        config.org_token   = "org_test_aaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        config.environment = "development"
        # workspace_slug unset
        message = described_class.message_for(config)
        expect(message).to include("workspace_slug is not set")
        expect(message).to include("c.workspace_slug")
        expect(message).to include("config/initializers/nurse_andrea.rb")
      end
    end

    context "when environment is missing" do
      it "returns the missing-environment message naming the allowed values" do
        config.org_token      = "org_test_aaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        config.workspace_slug = "smoke-app"
        config.environment    = nil
        message = described_class.message_for(config)
        expect(message).to include("environment is not set")
        expect(message).to include("production / staging / development")
      end
    end

    context "when environment is invalid" do
      it "returns the invalid-environment message naming the allowed values" do
        config.org_token      = "org_test_aaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        config.workspace_slug = "smoke-app"
        config.environment    = "qa"
        message = described_class.message_for(config)
        expect(message).to include("environment is invalid")
        expect(message).to include("production, staging, development")
      end
    end

    context "when workspace_slug is invalid" do
      it "returns the invalid-workspace_slug message describing the slug rules" do
        config.org_token      = "org_test_aaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        config.workspace_slug = "Bad_Slug!"
        config.environment    = "development"
        message = described_class.message_for(config)
        expect(message).to include("workspace_slug is invalid")
        expect(message).to include("lowercase letters, numbers, and hyphens")
      end
    end

    context "when fully valid" do
      it "returns nil (no diagnostic needed)" do
        config.org_token      = "org_test_aaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        config.workspace_slug = "smoke-app"
        config.environment    = "development"
        expect(described_class.message_for(config)).to be_nil
      end
    end
  end

  describe "Configuration#validation_diagnostic" do
    let(:config) { NurseAndrea.config }

    it "is :missing_org_token when org_token is blank" do
      config.workspace_slug = "smoke-app"
      config.environment    = "development"
      expect(config.validation_diagnostic).to eq(:missing_org_token)
    end

    it "is :invalid_environment when environment is unsupported" do
      config.org_token      = "org_test_aaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      config.workspace_slug = "smoke-app"
      config.environment    = "qa"
      expect(config.validation_diagnostic).to eq(:invalid_environment)
    end

    it "is :invalid_workspace_slug when slug fails validator" do
      config.org_token      = "org_test_aaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      config.workspace_slug = "Bad_Slug!"
      config.environment    = "development"
      expect(config.validation_diagnostic).to eq(:invalid_workspace_slug)
    end

    it "is nil when configuration is fully valid" do
      config.org_token      = "org_test_aaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      config.workspace_slug = "smoke-app"
      config.environment    = "development"
      expect(config.validation_diagnostic).to be_nil
    end

    it "keeps valid? equivalent to validation_diagnostic.nil?" do
      config.org_token      = "org_test_aaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      config.workspace_slug = "smoke-app"
      config.environment    = "development"
      expect(config.valid?).to be(true)
      expect(config.validation_diagnostic).to be_nil

      config.org_token = nil
      expect(config.valid?).to be(false)
      expect(config.validation_diagnostic).to eq(:missing_org_token)
    end
  end
end
