#!/usr/bin/env ruby
# frozen_string_literal: true

# Basic example of using sentry-rails23 in a Rails 2.3 application

require 'bundler/setup'

# Setup Rails 2.3 environment
ENV['RAILS_ENV'] = 'development'
RAILS_ROOT = File.expand_path('../', __FILE__)

require 'initializer'
require 'sentry-rails23'

# Configure Rails
Rails::Initializer.run do |config|
  config.frameworks -= [:active_resource, :action_mailer]
  config.action_controller.session = {
    :key => '_example_session',
    :secret => 'change_me_in_production'
  }
end

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

# Routes
ActionController::Routing::Routes.draw do |map|
  map.resources :posts, :member => { :error => :get }
  map.root :controller => 'home', :action => 'index'
end

# Initialize Sentry
Sentry::Rails23.init do |config|
  config.dsn = ENV['SENTRY_DSN'] || 'https://example@sentry.io/123456'
  config.environment = Rails.env
  config.debug = true
  config.enabled_environments = %w[development production]

  # Use HTTP transport for this example (real apps should use background transport)
  config.transport.transport_class = Sentry::HTTPTransport
end

puts "Example Rails 2.3 application initialized!"
puts "- Rails version: #{Rails::VERSION::STRING}"
puts "- Sentry initialized: #{Sentry.initialized?}"
puts "- Current user: #{ApplicationController.new.current_user.username}"

# Create some example data
unless Post.any?
  user = User.find_by_username('demo')
  user.posts.create!(:title => 'First Post', :content => 'Hello World!')
  user.posts.create!(:title => 'Second Post', :content => 'More content...')
  puts "- Created #{Post.count} example posts"
end

puts "\nTo start the server, add this to the bottom of the file:"
puts "require 'webrick'"
puts "server = WEBrick::HTTPServer.new(:Port => 3000)"
puts "trap('INT') { server.shutdown }"
puts "server.start"

puts "\nThen visit:"
puts "- http://localhost:3000/ (home page)"
puts "- http://localhost:3000/posts (list posts)"
puts "- http://localhost:3000/posts/1/error (trigger error)"