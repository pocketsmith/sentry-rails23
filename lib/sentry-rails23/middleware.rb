# frozen_string_literal: true

module Sentry
  module Rails23
    class Middleware
      def initialize(app)
        @app = app
      end

      def call(env)
        return @app.call(env) unless Sentry.initialized?

        # Clone hub for this thread
        Sentry.clone_hub_to_current_thread

        Sentry.with_scope do |scope|
          # Clear breadcrumbs for new request
          scope.clear_breadcrumbs

          # Set initial transaction name from path
          scope.set_transaction_name(env["PATH_INFO"], source: :url) if env["PATH_INFO"]

          # Set rack environment
          scope.set_rack_env(env)

          # Extract Rails 2.3 specific context
          extract_and_set_context(env, scope)

          # Start transaction for performance monitoring (optional)
          transaction = start_transaction(env, scope)
          scope.set_span(transaction) if transaction

          begin
            # Process request
            response = @app.call(env)

            # Finish transaction if started
            finish_transaction(transaction, response[0]) if transaction

            response
          rescue Exception => e
            # Capture exception
            capture_exception(e, env)

            # Finish transaction with error status
            finish_transaction(transaction, 500) if transaction

            # Re-raise to let Rails handle it
            raise
          end
        end
      end

      private

      def extract_and_set_context(env, scope)
        # Extract controller instance if available
        if env['action_controller.instance']
          controller = env['action_controller.instance']

          # Set transaction name
          transaction_name = "#{controller.class.name}##{controller.action_name}"
          scope.set_transaction_name(transaction_name, source: :view)

          # Set controller/action tags
          scope.set_tags(
            'rails.controller' => controller.class.name,
            'rails.action' => controller.action_name
          )

          # Extract user context if current_user is available
          if controller.respond_to?(:current_user)
            user = controller.current_user
            if user
              scope.set_user(
                id: user.id,
                username: user.respond_to?(:username) ? user.username : nil,
                email: user.respond_to?(:email) ? user.email : nil
              )
            end
          end
        end

        # Extract request ID
        if env['action_dispatch.request_id']
          scope.set_tags('request_id' => env['action_dispatch.request_id'])
        elsif env['HTTP_X_REQUEST_ID']
          scope.set_tags('request_id' => env['HTTP_X_REQUEST_ID'])
        end

        # Extract session data (filtered)
        if env['rack.session']
          filtered_session = filter_sensitive_data(env['rack.session'].to_hash)
          scope.set_context('session', filtered_session) unless filtered_session.empty?
        end

        # Extract params (filtered)
        if env['action_controller.params']
          filtered_params = filter_sensitive_data(env['action_controller.params'])
          scope.set_context('params', filtered_params) unless filtered_params.empty?
        end
      end

      def filter_sensitive_data(data)
        return {} unless data.is_a?(Hash)

        filtered = {}
        sensitive_keys = %w[password passwd secret token api_key private_key auth credit_card]

        data.each do |key, value|
          key_str = key.to_s.downcase
          if sensitive_keys.any? { |sensitive| key_str.include?(sensitive) }
            filtered[key] = '[FILTERED]'
          elsif value.is_a?(Hash)
            filtered[key] = filter_sensitive_data(value)
          else
            filtered[key] = value
          end
        end

        filtered
      end

      def capture_exception(exception, env)
        # Store event ID in env for error pages
        event = Sentry.capture_exception(exception)
        env['sentry.error_event_id'] = event.event_id if event
      end

      def start_transaction(env, scope)
        return nil unless Sentry.configuration.traces_sample_rate&.positive?

        options = {
          name: scope.transaction_name,
          source: scope.transaction_source,
          op: 'http.server'
        }

        transaction = Sentry.continue_trace(env, **options)
        Sentry.start_transaction(transaction: transaction, **options)
      end

      def finish_transaction(transaction, status)
        return unless transaction

        transaction.set_http_status(status)
        transaction.finish
      end
    end
  end
end