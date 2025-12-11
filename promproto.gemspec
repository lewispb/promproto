# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "promproto"
  spec.version = "0.1.0"
  spec.authors = ["Lewis Buckley"]
  spec.email = ["lewis@basecamp.com"]

  spec.summary = "CLI tool to fetch and display Prometheus metrics in protobuf format"
  spec.description = "A command-line tool that fetches Prometheus metrics using the protobuf exposition format and renders them with color-coded output. Supports both classic and native histograms."
  spec.homepage = "https://github.com/lewispb/promproto"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir.glob("{lib,exe}/**/*") + %w[README.md LICENSE.txt]
  spec.bindir = "exe"
  spec.executables = ["promproto"]
  spec.require_paths = ["lib"]

  spec.add_dependency "google-protobuf", ">= 3.21"
end
