$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "active_support/core_ext/object/blank"
require "nurse_andrea"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.around(:each) do |example|
    NurseAndrea.reset_config!
    example.run
    NurseAndrea.reset_config!
  end
end
