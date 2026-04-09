require "spec_helper"

RSpec.describe NurseAndrea do
  it "exposes a SemVer-shaped version constant" do
    expect(NurseAndrea::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end

  it "is on the current SDK release line (0.1.x)" do
    expect(NurseAndrea::VERSION).to start_with("0.1.")
  end
end
