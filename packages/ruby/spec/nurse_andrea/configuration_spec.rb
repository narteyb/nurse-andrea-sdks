require "spec_helper"

RSpec.describe NurseAndrea::Configuration do
  let(:config) { described_class.new }

  describe "#initialize" do
    it "defaults host to nurseandrea.io" do
      expect(config.host).to eq("https://nurseandrea.io")
    end

    it "auto-detects environment via EnvironmentDetector" do
      expect(NurseAndrea::EnvironmentDetector).to receive(:detect).and_return("staging")
      expect(described_class.new.environment).to eq("staging")
    end
  end

  describe "migration errors on legacy fields" do
    %i[api_key token ingest_token].each do |legacy|
      it "raises a MigrationError when reading #{legacy}" do
        expect { config.send(legacy) }.to raise_error(
          NurseAndrea::MigrationError,
          /no longer supported.*org_token \+ workspace_slug \+ environment/
        )
      end

      it "raises a MigrationError when writing #{legacy}=" do
        expect { config.send("#{legacy}=", "anything") }.to raise_error(
          NurseAndrea::MigrationError,
          /no longer supported/
        )
      end
    end

    it "MigrationError descends from ConfigurationError" do
      expect(NurseAndrea::MigrationError.ancestors).to include(NurseAndrea::ConfigurationError)
    end
  end

  describe "#validate!" do
    before do
      config.org_token      = "org_abc123"
      config.workspace_slug = "checkout"
      config.environment    = "production"
    end

    it "passes a fully-populated valid config" do
      expect { config.validate! }.not_to raise_error
    end

    it "fails when org_token is missing" do
      config.org_token = nil
      expect { config.validate! }.to raise_error(NurseAndrea::ConfigurationError, /org_token is required/)
    end

    it "fails when org_token is whitespace" do
      config.org_token = "   "
      expect { config.validate! }.to raise_error(NurseAndrea::ConfigurationError, /org_token is required/)
    end

    it "fails when workspace_slug is missing" do
      config.workspace_slug = nil
      expect { config.validate! }.to raise_error(NurseAndrea::ConfigurationError, /workspace_slug is required/)
    end

    it "fails when environment is missing" do
      config.environment = nil
      expect { config.validate! }.to raise_error(NurseAndrea::ConfigurationError, /environment is required/)
    end

    it "fails when environment is not in the supported set" do
      config.environment = "qa"
      expect { config.validate! }.to raise_error(
        NurseAndrea::ConfigurationError,
        /environment must be one of production, staging, development/
      )
    end

    it "fails when workspace_slug is invalid format" do
      config.workspace_slug = "Bad_Slug"
      expect { config.validate! }.to raise_error(
        NurseAndrea::ConfigurationError,
        /workspace_slug.*is invalid.*lowercase/
      )
    end
  end

  describe "URL builders" do
    it "appends the api path to host without double-slashes" do
      config.host = "http://localhost:4500/"
      expect(config.ingest_url).to eq("http://localhost:4500/api/v1/ingest")
    end
  end
end
