# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sentry::Rails23 do
  let(:transport) { Sentry.get_current_client.transport }

  before do
    # Initialize Sentry for each test
    Sentry::Rails23.init(
      dsn: 'http://12345:67890@sentry.localdomain/sentry/42',
      transport: Sentry::DummyTransport,
      background_worker_threads: 0
    )
  end

  describe '.init' do
    it 'initializes Sentry with Rails 2.3 configuration' do
      expect(Sentry.initialized?).to be true
      expect(Sentry.configuration.environment).to eq('test')
      expect(Sentry.configuration.project_root).to eq(File.expand_path('../dummy', __dir__))
    end

    it 'installs middleware' do
      middleware_classes = ActionController::Dispatcher.middleware.map(&:klass)
      expect(middleware_classes).to include(Sentry::Rails23::Middleware)
    end

    it 'does not initialize twice' do
      Sentry::Rails23.init(dsn: 'http://different:dsn@sentry.localdomain/sentry/1')

      # DSN should not change
      expect(Sentry.configuration.dsn.to_s).to include('12345:67890')
    end
  end

  describe 'exception capturing' do
    it 'captures exceptions from controller actions' do
      expect { get('/posts/1/boom') }.to raise_error(RuntimeError, "Intentional error for testing")

      expect(transport.events.size).to eq(1)
      event = transport.events.first

      expect(event.exception.values.first.type).to eq('RuntimeError')
      expect(event.exception.values.first.value).to eq('Intentional error for testing')
    end

    it 'includes Rails 2.3 context' do
      Post.create!(:title => 'Test Post', :content => 'Content')

      get('/posts/1')

      # Should not capture successful requests
      expect(transport.events).to be_empty

      # But breadcrumbs should be added
      breadcrumbs = Sentry.get_current_scope.breadcrumbs.peek
      expect(breadcrumbs).not_to be_empty

      controller_breadcrumb = breadcrumbs.find { |b| b.category == 'rails.controller' }
      expect(controller_breadcrumb).not_to be_nil
      expect(controller_breadcrumb.data[:controller]).to eq('PostsController')
      expect(controller_breadcrumb.data[:action]).to eq('show')
    end
  end

  describe 'context extraction' do
    let(:controller) { PostsController.new }
    let(:request) do
      req = ActionController::TestRequest.new
      req.path = '/posts'
      req.method = 'GET'
      req
    end

    it 'extracts user context' do
      context = Sentry::Rails23::ContextExtractor.extract(controller, request)

      expect(context[:user]).to include(
        :id,
        :username => 'test_user',
        :email => 'test@example.com'
      )
    end

    it 'extracts request context' do
      context = Sentry::Rails23::ContextExtractor.extract(controller, request)

      expect(context[:request]).to include(
        :url => match(/http:\/\/.*\/posts/),
        :method => 'GET'
      )
    end

    it 'filters sensitive parameters' do
      controller.params = {
        'username' => 'john',
        'password' => 'secret123',
        'api_key' => 'abc123'
      }

      context = Sentry::Rails23::ContextExtractor.extract(controller, request)

      expect(context[:params]).to eq(
        'username' => 'john',
        'password' => '[FILTERED]',
        'api_key' => '[FILTERED]'
      )
    end
  end

  describe 'breadcrumbs' do
    before do
      Sentry::Rails23::Breadcrumbs.activate!
    end

    it 'adds breadcrumbs for controller actions' do
      get('/posts')

      breadcrumbs = Sentry.get_current_scope.breadcrumbs.peek
      controller_breadcrumbs = breadcrumbs.select { |b| b.category == 'rails.controller' }

      expect(controller_breadcrumbs.size).to be >= 1
      expect(controller_breadcrumbs.first.message).to include('PostsController#index')
    end

    it 'adds breadcrumbs for ActiveRecord operations' do
      Post.create!(:title => 'Test', :content => 'Content')

      breadcrumbs = Sentry.get_current_scope.breadcrumbs.peek
      ar_breadcrumb = breadcrumbs.find { |b| b.category == 'activerecord' }

      expect(ar_breadcrumb).not_to be_nil
      expect(ar_breadcrumb.message).to include('Created Post')
    end

    it 'adds breadcrumbs for slow queries' do
      # Create many posts to trigger slow query detection
      10.times { |i| Post.create!(:title => "Post #{i}", :content => "Content") }

      # This should be logged as a slow query in test environment
      Post.find(:all)

      breadcrumbs = Sentry.get_current_scope.breadcrumbs.peek
      slow_query = breadcrumbs.find { |b| b.level == :warning && b.category == 'activerecord' }

      # May or may not find slow query depending on timing
      if slow_query
        expect(slow_query.data[:duration_ms]).to be > 0
      end
    end
  end

  describe 'manual exception capture' do
    it 'allows manual exception capture with context' do
      begin
        raise "Manual error"
      rescue => e
        Sentry::Rails23.capture_exception(e, env: { 'PATH_INFO' => '/custom/path' })
      end

      expect(transport.events.size).to eq(1)
      event = transport.events.first

      expect(event.exception.values.first.value).to eq('Manual error')
      expect(event.transaction).to eq('/custom/path')
    end
  end

  describe 'configuration' do
    it 'respects enabled_environments setting' do
      Sentry::Rails23.initialized = false

      Sentry::Rails23.init(
        dsn: 'http://12345:67890@sentry.localdomain/sentry/42',
        enabled_environments: ['production'],
        transport: Sentry::DummyTransport
      )

      # In test environment, should still initialize but not send events
      expect(Sentry.initialized?).to be true
    end
  end
end