# frozen_string_literal: true

source "https://rubygems.org"

# Load gem dependencies from gemspec
gemspec

# Use makandra's Rails 2.3 LTS fork
gem "rails", git: "https://github.com/makandra/rails.git", branch: "2-3-lts"

# Ruby 3.x compatibility
gem "ruby3-backward-compatibility", "~> 1.0" if RUBY_VERSION >= "3.0"

# Testing
group :test do
  gem "rspec", "~> 3.0"
  gem "rspec-rails", "~> 1.3"
  gem "sqlite3", "~> 1.7", platform: :ruby
  gem "simplecov", require: false
end

# Development tools
group :development do
  gem "rake"
  gem "pry"
end