# frozen_string_literal: true

require 'sentry-ruby'
require 'sentry-rails23/middleware'
require 'sentry-rails23/context_extractor'
require 'sentry-rails23/breadcrumbs'
require 'sentry-rails23/configuration'

module Sentry
  module Rails23
    VERSION = "1.0.0"
    class Error < StandardError; end

    class << self
      attr_accessor :initialized

      # Main initialization method - single entry point
      def init(config = {})
        return if initialized

        # Initialize Sentry SDK
        Sentry.init do |sentry_config|
          # Apply configuration
          config.each do |key, value|
            sentry_config.public_send("#{key}=", value) if sentry_config.respond_to?("#{key}=")
          end

          # Rails 2.3 specific defaults
          sentry_config.project_root ||= rails_root
          sentry_config.environment ||= rails_env
          sentry_config.sdk_logger ||= rails_logger
          sentry_config.release ||= detect_release

          # Set appropriate breadcrumb loggers
          sentry_config.breadcrumbs_logger ||= [:sentry_logger, :http_logger]

          yield sentry_config if block_given?
        end

        # Install Rails 2.3 integrations
        install_middleware!
        install_exception_handler!
        install_context_extraction!
        install_breadcrumbs!

        self.initialized = true

        # Log successful initialization
        if Sentry.configuration.debug
          puts "[Sentry] Rails 2.3 integration initialized successfully"
          puts "[Sentry] Environment: #{rails_env}"
          puts "[Sentry] Project root: #{rails_root}"
        end
      end

      private

      def install_middleware!
        if defined?(ActionController::Dispatcher)
          ActionController::Dispatcher.middleware.use(Sentry::Rails23::Middleware)
        else
          raise Error, "ActionController::Dispatcher not found - is this Rails 2.3?"
        end
      end

      def install_exception_handler!
        # Hook into Rails 2.3's rescue_action methods
        ActionController::Base.class_eval do
          # Hook rescue_action_in_public (production mode)
          alias_method :rescue_action_in_public_without_sentry, :rescue_action_in_public

          def rescue_action_in_public(exception)
            # Capture exception to Sentry
            Sentry::Rails23.capture_exception(exception, env: request.env)

            # Call original handler
            rescue_action_in_public_without_sentry(exception)
          end

          # Hook rescue_action (all modes, including development)
          alias_method :rescue_action_without_sentry, :rescue_action

          def rescue_action(exception)
            # Capture exception to Sentry
            Sentry::Rails23.capture_exception(exception, env: request.env)

            # Call original handler
            rescue_action_without_sentry(exception)
          end

          # Also hook rescue_action_locally for development mode
          if method_defined?(:rescue_action_locally)
            alias_method :rescue_action_locally_without_sentry, :rescue_action_locally

            def rescue_action_locally(exception)
              Sentry::Rails23.capture_exception(exception, env: request.env)

              # Call original handler
              rescue_action_locally_without_sentry(exception)
            end
          end
        end
      end

      def install_context_extraction!
        # Add a before_filter to all controllers for context extraction
        ActionController::Base.class_eval do
          before_filter :extract_sentry_context

          private

          def extract_sentry_context
            begin
              Sentry.with_scope do |scope|
                # Extract and set context
                context = Sentry::Rails23::ContextExtractor.extract(self, request)

                scope.set_user(context[:user]) if context[:user]
                scope.set_tags(context[:tags]) if context[:tags]
                scope.set_context("request", context[:request]) if context[:request]
                scope.set_context("session", context[:session]) if context[:session]
              end
            rescue => e
              # Log the error but don't let it break the request
              Rails.logger.error "[Sentry] Failed to extract context: #{e.message}" if defined?(Rails.logger)
              # Re-raise so it can be caught by our exception handlers
              raise
            end
          end
        end
      end

      def install_breadcrumbs!
        Sentry::Rails23::Breadcrumbs.activate!
      end

      def rails_root
        if defined?(RAILS_ROOT)
          RAILS_ROOT
        elsif defined?(Rails) && Rails.respond_to?(:root)
          Rails.root.to_s
        else
          Dir.pwd
        end
      end

      def rails_env
        if defined?(RAILS_ENV)
          RAILS_ENV
        elsif defined?(Rails) && Rails.respond_to?(:env)
          Rails.env.to_s
        else
          ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'
        end
      end

      def rails_logger
        if defined?(Rails) && Rails.respond_to?(:logger)
          Rails.logger
        elsif defined?(RAILS_DEFAULT_LOGGER)
          RAILS_DEFAULT_LOGGER
        else
          Logger.new(STDOUT)
        end
      end

      def detect_release
        # Try to detect release from common deployment files
        revision_file = File.join(rails_root, 'REVISION')
        if File.exist?(revision_file)
          File.read(revision_file).strip[0..11] # First 12 chars of SHA
        elsif File.exist?(File.join(rails_root, '.git'))
          `git rev-parse HEAD`.strip[0..11] rescue nil
        else
          nil
        end
      end
    end

    # Capture exception helper
    def self.capture_exception(exception, options = {})
      return unless Sentry.initialized?

      Sentry.with_scope do |scope|
        # Add Rails 2.3 specific context
        if options[:env]
          scope.set_rack_env(options[:env])
          transaction_name = extract_transaction_name(options[:env])
          scope.set_transaction_name(transaction_name) if transaction_name
        end

        Sentry.capture_exception(exception)
      end
    end

    def self.extract_transaction_name(env)
      if env['action_controller.instance']
        controller = env['action_controller.instance']
        "#{controller.class.name}##{controller.action_name}"
      elsif env['PATH_INFO']
        env['PATH_INFO']
      else
        nil
      end
    end
  end
end
