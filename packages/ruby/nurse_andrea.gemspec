require_relative "lib/nurse_andrea/version"

Gem::Specification.new do |spec|
  spec.name        = "nurse_andrea"
  spec.version     = NurseAndrea::VERSION
  spec.authors     = [ "Ago AI LLC" ]
  spec.email       = [ "hello@nurseandrea.io" ]
  spec.summary     = "Observability SDK for Rails — ships logs and metrics to NurseAndrea"
  spec.description = "One-line integration to send your Rails app's logs and metrics to the NurseAndrea observability platform."
  spec.homepage    = "https://nurseandrea.io"
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 3.1"

  spec.metadata = {
    "homepage_uri"          => spec.homepage,
    "source_code_uri"       => "https://github.com/narteyb/nurse-andrea-sdks",
    "changelog_uri"         => "https://github.com/narteyb/nurse-andrea-sdks/blob/main/packages/ruby/CHANGELOG.md",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir.chdir(__dir__) do
    Dir["{app,config,lib}/**/*", "README.md", "CHANGELOG.md", "nurse_andrea.gemspec"]
      .reject { |f| File.directory?(f) }
  end

  spec.require_paths = [ "lib" ]
end
