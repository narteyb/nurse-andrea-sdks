require "spec_helper"
require "webmock/rspec"

RSpec.describe NurseAndrea::HttpClient do
  let(:client) { described_class.new }
  let(:url)    { "http://localhost:4500/api/v1/ingest" }

  before do
    NurseAndrea.reset_config!
    NurseAndrea.configure do |c|
      c.org_token      = "org_test_token_32chars_xxxxxxxxxx"
      c.workspace_slug = "checkout"
      c.environment    = "development"
      c.host           = "http://localhost:4500"
      c.debug          = false
    end
    described_class.reset_rejection_state!
  end

  after do
    described_class.reset_rejection_state!
    WebMock.reset!
  end

  describe "request headers" do
    it "sends the new auth contract" do
      stub = stub_request(:post, url)
        .with(headers: {
          "Authorization"             => "Bearer org_test_token_32chars_xxxxxxxxxx",
          "X-Nurseandrea-Workspace"   => "checkout",
          "X-Nurseandrea-Environment" => "development"
        })
        .to_return(status: 200, body: "{}")

      client.post(url, { events: [] })
      expect(stub).to have_been_requested
    end

    it "sends an SDK identity header in language/version form" do
      stub = stub_request(:post, url)
        .with(headers: { "X-Nurseandrea-Sdk" => "ruby/#{NurseAndrea::VERSION}" })
        .to_return(status: 200, body: "{}")

      client.post(url, { events: [] })
      expect(stub).to have_been_requested
    end
  end

  describe "response handling" do
    it "returns true on 200" do
      stub_request(:post, url).to_return(status: 200, body: "{}")
      expect(client.post(url, {})).to be true
    end

    it "returns true on 202 (pending workspace)" do
      stub_request(:post, url).to_return(status: 202, body: "{}")
      expect(client.post(url, {})).to be true
    end

    it "returns false on 401" do
      stub_request(:post, url).to_return(
        status: 401,
        body: { error: "invalid_org_token", message: "bad token" }.to_json
      )
      expect(client.post(url, {})).to be false
    end

    it "stays silent for the first 4 consecutive rejections" do
      stub_request(:post, url).to_return(
        status: 401,
        body: { error: "invalid_org_token" }.to_json
      )

      output = capture_stderr { 4.times { client.post(url, {}) } }
      expect(output).not_to include("Ingest rejected")
    end

    it "warns once after 5 consecutive rejections of the same error code" do
      stub_request(:post, url).to_return(
        status: 401,
        body: { error: "invalid_org_token" }.to_json
      )

      output = capture_stderr { 8.times { client.post(url, {}) } }
      occurrences = output.scan("Ingest rejected").size
      expect(occurrences).to eq(1)
      expect(output).to include("invalid_org_token")
      expect(output).to include("Check NURSE_ANDREA_ORG_TOKEN")
    end

    it "resets the rejection counter on a successful response" do
      stub_request(:post, url)
        .to_return({ status: 401, body: { error: "invalid_org_token" }.to_json }).times(4)
        .then.to_return({ status: 200, body: "{}" }).times(1)
        .then.to_return({ status: 401, body: { error: "invalid_org_token" }.to_json })

      output = capture_stderr do
        4.times { client.post(url, {}) }
        client.post(url, {})
        4.times { client.post(url, {}) }
      end
      expect(output).not_to include("Ingest rejected")
    end

    it "warns again when a different error code starts dominating" do
      stub_request(:post, url)
        .to_return({ status: 401, body: { error: "invalid_org_token" }.to_json }).times(5)
        .then.to_return({ status: 403, body: { error: "workspace_rejected" }.to_json })

      output = capture_stderr do
        5.times { client.post(url, {}) }
        5.times { client.post(url, {}) }
      end
      expect(output.scan("Ingest rejected").size).to be >= 2
      expect(output).to include("invalid_org_token")
      expect(output).to include("workspace_rejected")
    end

    it "does not count 5xx as a rejection" do
      stub_request(:post, url).to_return(status: 503, body: "")
      output = capture_stderr { 6.times { client.post(url, {}) } }
      expect(output).not_to include("Ingest rejected")
    end
  end

  def capture_stderr
    original = $stderr
    $stderr = StringIO.new
    yield
    $stderr.string
  ensure
    $stderr = original
  end
end
