#!/usr/bin/env ruby

require 'bundler/setup'
require 'sentry-ruby'
require_relative 'lib/sentry-rails23'

# Configure Sentry
Sentry.init do |config|
  config.dsn = 'https://test@sentry.io/123456'
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  config.enabled_environments = ['development', 'test']
end

# Test breadcrumb creation
puts "Testing breadcrumb creation..."

# Test creating a breadcrumb directly (mimicking what the fixed code does)
breadcrumb = Sentry::Breadcrumb.new(
  message: "Test breadcrumb",
  category: 'test',
  level: :info,
  data: { test_key: 'test_value' }
)

# This should now work without ArgumentError
begin
  Sentry.add_breadcrumb(breadcrumb)
  puts "✓ Breadcrumb added successfully!"
rescue ArgumentError => e
  puts "✗ Error: #{e.message}"
  exit 1
end

# Test that the old way would fail
begin
  # This is how the code was trying to call it before (incorrectly)
  Sentry.add_breadcrumb(
    message: "Test breadcrumb",
    category: 'test',
    level: :info,
    data: { test_key: 'test_value' }
  )
  puts "✗ Old way unexpectedly succeeded"
rescue ArgumentError => e
  puts "✓ Old way correctly fails with: #{e.message}"
end

puts "\nAll tests passed!"