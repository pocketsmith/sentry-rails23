# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "sentry-rails23"
  spec.version       = "1.0.0"
  spec.authors       = ["Sentry Team"]
  spec.email         = ["sdk@sentry.io"]
  spec.summary       = "Sentry integration specifically for Rails 2.3 LTS"
  spec.description   = "A clean, focused Sentry integration for Rails 2.3 LTS applications with full context and breadcrumb support"
  spec.homepage      = "https://github.com/getsentry/sentry-ruby"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 2.3"

  spec.files         = Dir["lib/**/*", "LICENSE", "README.md"]
  spec.require_paths = ["lib"]

  # Rails 2.3 LTS from makandra
  spec.add_dependency "rails", "~> 2.3.18"

  # Core Sentry SDK
  spec.add_dependency "sentry-ruby", "~> 5.0"

  # Ruby 3.x compatibility for Rails 2.3
  spec.add_dependency "ruby3-backward-compatibility", "~> 1.0" if RUBY_VERSION >= "3.0"

  # Development dependencies
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rspec-rails", "~> 1.3"
  spec.add_development_dependency "sqlite3", "~> 1.7"
  spec.add_development_dependency "rake"
end