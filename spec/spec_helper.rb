# frozen_string_literal: true

require 'bundler/setup'
require 'simplecov'

SimpleCov.start do
  add_filter '/spec/'
  add_filter '/vendor/'
end

# Load Rails 2.3 LTS
ENV['RAILS_ENV'] = 'test'
ENV['RAILS_ROOT'] = File.expand_path('../dummy', __FILE__)

# Load the dummy Rails 2.3 application
require File.join(ENV['RAILS_ROOT'], 'config', 'environment')

# Setup database
ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database => ':memory:'
)

# Load our gem
require 'sentry-rails23'

# Test helpers
require 'sentry/test_helper'

# Define test schema
ActiveRecord::Schema.define do
  create_table :users do |t|
    t.string :username
    t.string :email
    t.timestamps
  end

  create_table :posts do |t|
    t.string :title
    t.text :content
    t.integer :user_id
    t.timestamps
  end
end

# RSpec configuration
RSpec.configure do |config|
  config.include Sentry::TestHelper

  config.before(:each) do
    # Reset Sentry state
    if Sentry.initialized?
      Sentry.get_current_scope.clear
      Sentry.get_current_scope.clear_breadcrumbs
    end

    # Clear transport events
    if Sentry.initialized? && Sentry.get_current_client
      client = Sentry.get_current_client
      client.transport.events.clear if client.transport.respond_to?(:events)
    end
  end

  config.after(:each) do
    # Clean up Sentry
    Sentry::Rails23.initialized = false
  end

  # Test helpers for Rails 2.3 using Rack
  def get(path, params = {})
    env = Rack::MockRequest.env_for(path, :params => params, :method => 'GET')

    # Add Rails 2.3 specific env variables
    env['action_controller.rescue.request'] = ActionController::Request.new(env)
    env['action_controller.rescue.response'] = ActionController::Response.new

    status, headers, response = ActionController::Dispatcher.new.call(env)

    # Return a mock response object
    mock_response = Struct.new(:status, :headers, :body).new(status, headers, response.body)
    mock_response
  end

  def post(path, params = {})
    env = Rack::MockRequest.env_for(path, :params => params, :method => 'POST')

    # Add Rails 2.3 specific env variables
    env['action_controller.rescue.request'] = ActionController::Request.new(env)
    env['action_controller.rescue.response'] = ActionController::Response.new

    status, headers, response = ActionController::Dispatcher.new.call(env)

    # Return a mock response object
    mock_response = Struct.new(:status, :headers, :body).new(status, headers, response.body)
    mock_response
  end
end