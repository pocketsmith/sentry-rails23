#!/usr/bin/env ruby

require 'bundler/setup'
require 'action_controller'
require 'sentry-ruby'
require_relative 'lib/sentry-rails23'

# Mock Rails environment
module Rails
  def self.env
    'test'
  end

  def self.logger
    @logger ||= Logger.new(STDOUT)
  end
end

RAILS_ENV = 'test'
RAILS_ROOT = Dir.pwd

# Initialize Sentry with test configuration
Sentry::Rails23.init(
  dsn: 'https://test@sentry.io/123456',
  enabled_environments: ['test', 'development', 'production'],
  debug: true
)

# Create a test controller
class TestController < ActionController::Base
  before_filter :problematic_filter

  def index
    render :text => "Hello"
  end

  private

  def problematic_filter
    # This will raise NameError like in the user's case
    puts prefix  # undefined variable
  end
end

# Create a mock request
class MockRequest
  attr_accessor :env, :format, :request_method

  def initialize
    @env = {
      'PATH_INFO' => '/test',
      'REQUEST_METHOD' => 'GET',
      'action_controller.instance' => nil
    }
    @format = OpenStruct.new(:to_s => 'html')
    @request_method = 'GET'
  end
end

# Test exception capture
puts "\nTesting exception capture from before_filter..."
puts "=" * 50

controller = TestController.new
controller.instance_variable_set(:@_request, MockRequest.new)
controller.instance_variable_set(:@action_name, 'index')

# Mock the request method
def controller.request
  @_request
end

# Capture any Sentry events
captured_events = []
Sentry.configuration.before_send = lambda do |event, hint|
  captured_events << event
  puts "\n✓ Exception captured by Sentry!"
  puts "  Exception: #{event.exception.values.first.type}"
  puts "  Message: #{event.exception.values.first.value}"
  event
end

begin
  # Simulate what Rails does
  controller.send(:problematic_filter)
rescue NameError => e
  puts "\n✗ NameError raised: #{e.message}"

  # This is what our rescue_action hook should do
  if controller.respond_to?(:rescue_action)
    controller.rescue_action(e)
  else
    # Manually call our capture method
    Sentry::Rails23.capture_exception(e, env: controller.request.env)
  end
end

puts "\n" + "=" * 50
if captured_events.any?
  puts "✓ Test passed! Exception was sent to Sentry."
else
  puts "✗ Test failed! Exception was NOT sent to Sentry."
end