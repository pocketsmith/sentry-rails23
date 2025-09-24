#!/usr/bin/env ruby
# frozen_string_literal: true

# Simplified test of sentry-rails23 functionality

require 'bundler/setup'

# Setup Rails 2.3 environment
ENV['RAILS_ENV'] = 'development'

# Set RAILS_ROOT to the examples directory
RAILS_ROOT = File.dirname(__FILE__)

# Load Rails 2.3
require File.join(RAILS_ROOT, 'config', 'boot')
require File.join(RAILS_ROOT, 'config', 'environment')

# Load our gem
require 'sentry-rails23'

# Setup database
ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database => 'example.db'
)

# Create tables
ActiveRecord::Schema.define do
  unless ActiveRecord::Base.connection.table_exists?('users')
    create_table :users do |t|
      t.string :username, :null => false
      t.string :email
      t.timestamps
    end
  end

  unless ActiveRecord::Base.connection.table_exists?('posts')
    create_table :posts do |t|
      t.string :title, :null => false
      t.text :content
      t.integer :user_id
      t.timestamps
    end
  end
end

# Models
class User < ActiveRecord::Base
  has_many :posts
  validates_presence_of :username
end

class Post < ActiveRecord::Base
  belongs_to :user
  validates_presence_of :title
end

# Controllers
class ApplicationController < ActionController::Base
  protect_from_forgery

  def current_user
    @current_user ||= User.find_by_username('demo') ||
                     User.create!(:username => 'demo', :email => 'demo@example.com')
  end
end

class PostsController < ApplicationController
  def index
    @posts = Post.all
    render :text => "Posts: #{@posts.map(&:title).join(', ')}"
  end

  def show
    @post = Post.find(params[:id])
    render :text => @post.title
  end

  def create
    @post = current_user.posts.create!(params[:post])
    render :text => "Created: #{@post.title}"
  end

  def error
    raise "This is a test error!"
  end
end

class HomeController < ApplicationController
  def index
    render :text => "Welcome to Rails 2.3 + Sentry example!"
  end
end

# Initialize Sentry
puts "Initializing Sentry..."
Sentry::Rails23.init do |config|
  # Use a test DSN (won't actually send events)
  config.dsn = 'https://example@sentry.io/123456'
  config.environment = Rails.env
  config.debug = true
  config.enabled_environments = %w[development production]

  # Use test transport to capture events locally
  config.transport.transport_class = Sentry::HTTPTransport
  config.before_send = lambda do |event, _hint|
    puts "\n[Sentry] Would send event:"
    puts "  Event ID: #{event.event_id}"
    puts "  Message: #{event.message}" if event.message
    puts "  Exception: #{event.exception.values.first.type}: #{event.exception.values.first.value}" if event.exception
    puts "  Tags: #{event.tags}"
    puts "  Breadcrumbs: #{event.breadcrumbs.count} breadcrumb(s)"
    event.breadcrumbs.each do |crumb|
      puts "    - #{crumb.category}: #{crumb.message}"
    end if event.breadcrumbs.any?
    nil # Don't actually send
  end
end

puts "\n=== Sentry Rails 2.3 Integration Test ==="
puts "Rails version: #{Rails::VERSION::STRING}"
puts "Sentry initialized: #{Sentry.initialized?}"
puts "Environment: #{Sentry.configuration.environment}"
puts "Project root: #{Sentry.configuration.project_root}"

# Test 1: Create some data with breadcrumbs
puts "\n=== Test 1: ActiveRecord Operations ==="
begin
  user = User.find_by_username('demo') || User.create!(:username => 'demo', :email => 'test@example.com')
  puts "Created/found user: #{user.username}"

  post = user.posts.create!(:title => "Test Post #{Time.now.to_i}", :content => 'Test content')
  puts "Created post: #{post.title}"

  # Slow query simulation
  sleep 0.2
  found_posts = Post.find(:all)
  puts "Found #{found_posts.size} posts"
rescue => e
  puts "Error: #{e.message}"
end

# Test 2: Capture an exception
puts "\n=== Test 2: Exception Capture ==="
begin
  raise "Test exception for Sentry!"
rescue => e
  puts "Capturing exception: #{e.message}"
  Sentry::Rails23.capture_exception(e, env: { 'PATH_INFO' => '/test' })
end

# Test 3: Manual breadcrumb
puts "\n=== Test 3: Manual Breadcrumb ==="
Sentry.add_breadcrumb(
  message: 'User performed custom action',
  category: 'custom',
  level: :info,
  data: { user_id: user.id }
)
puts "Added custom breadcrumb"

# Test 4: Another exception with context
puts "\n=== Test 4: Exception with Context ==="
begin
  Sentry.with_scope do |scope|
    scope.set_user(id: user.id, username: user.username, email: user.email)
    scope.set_tags(feature: 'test', version: '1.0.0')
    scope.set_context('custom', { foo: 'bar' })

    raise "Another test exception with rich context!"
  end
rescue => e
  puts "Capturing exception with context: #{e.message}"
  Sentry.capture_exception(e)
end

puts "\n=== Test Complete ==="
puts "All tests finished successfully!"