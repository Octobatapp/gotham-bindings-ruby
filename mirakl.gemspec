# frozen_string_literal: true

$LOAD_PATH.unshift(::File.join(::File.dirname(__FILE__), "lib"))

require "mirakl/version"

Gem::Specification.new do |s|
  s.name = "mirakl"
  s.version = Mirakl::VERSION
  s.required_ruby_version = ">= 2.1.0"
  s.summary = "Ruby bindings for the Mirakl API"
  s.description = ""
  s.author = "Mirakl"
  s.email = "gaultier.laperche@mirakl.com"
  s.homepage = "https://www.mirakl.com/"
  s.license = "MIT"

  s.metadata = {
    "bug_tracker_uri"   => "https://github.com/mirakl/mirakl-ruby/issues",
    "changelog_uri"     =>
      "https://github.com/mirakl/mirakl-ruby/blob/master/CHANGELOG.md",
    "github_repo"       => "ssh://github.com/mirakl/mirakl-ruby",
  }

  s.add_dependency("faraday", "~> 1.8")
  s.add_dependency("net-http-persistent", "~> 3.0")

  s.files = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- test/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n")
                                           .map { |f| ::File.basename(f) }
  s.require_paths = ["lib"]
end
