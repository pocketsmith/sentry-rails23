# frozen_string_literal: true

module Sentry
  module Rails23
    class ContextExtractor
      # Extract comprehensive context from controller and request
      def self.extract(controller, request)
        context = {}

        # User context
        context[:user] = extract_user(controller)

        # Request context
        context[:request] = extract_request(request)

        # Session context
        context[:session] = extract_session(controller)

        # Tags for categorization
        context[:tags] = {
          'rails.controller' => controller.class.name,
          'rails.action' => controller.action_name,
          'rails.format' => request.format.to_s,
          'rails.method' => request.request_method
        }

        # Additional Rails 2.3 specific context
        if controller.respond_to?(:params)
          context[:params] = filter_params(controller.params)
        end

        context
      end

      private

      def self.extract_user(controller)
        return nil unless controller.respond_to?(:current_user)

        user = controller.current_user
        return nil unless user

        user_context = { id: user.id }

        # Add optional user attributes
        user_context[:username] = user.username if user.respond_to?(:username)
        user_context[:username] = user.login if user.respond_to?(:login)
        user_context[:email] = user.email if user.respond_to?(:email)
        user_context[:name] = user.name if user.respond_to?(:name)

        # Add custom attributes if they exist
        if user.respond_to?(:sentry_context)
          user_context.merge!(user.sentry_context)
        end

        user_context
      end

      def self.extract_request(request)
        {
          url: build_url(request),
          method: request.request_method,
          headers: extract_headers(request),
          query_string: request.query_string,
          cookies: extract_cookies(request),
          remote_ip: request.remote_ip,
          user_agent: request.user_agent
        }
      end

      def self.extract_session(controller)
        return {} unless controller.respond_to?(:session)

        session = controller.session
        return {} unless session

        # Convert session to hash and filter sensitive data
        session_hash = session.respond_to?(:to_hash) ? session.to_hash : session.to_h
        filter_sensitive_data(session_hash)
      end

      def self.build_url(request)
        # Build full URL for Rails 2.3
        protocol = request.ssl? ? 'https' : 'http'
        host = request.host_with_port
        path = request.path

        "#{protocol}://#{host}#{path}"
      end

      def self.extract_headers(request)
        headers = {}

        # Extract relevant HTTP headers
        request.env.each do |key, value|
          next unless key.start_with?('HTTP_')
          next if key == 'HTTP_COOKIE' # Don't include raw cookies in headers

          # Convert HTTP_HEADER_NAME to Header-Name format
          header_name = key[5..-1].split('_').map(&:capitalize).join('-')
          headers[header_name] = value.to_s
        end

        # Add content type and length if present
        headers['Content-Type'] = request.content_type if request.content_type
        headers['Content-Length'] = request.content_length.to_s if request.content_length

        headers
      end

      def self.extract_cookies(request)
        return {} unless request.cookies

        # Filter sensitive cookie values
        filtered_cookies = {}
        request.cookies.each do |key, value|
          if sensitive_key?(key)
            filtered_cookies[key] = '[FILTERED]'
          else
            filtered_cookies[key] = value
          end
        end

        filtered_cookies
      end

      def self.filter_params(params)
        return {} unless params.is_a?(Hash)

        filter_sensitive_data(params)
      end

      def self.filter_sensitive_data(data)
        return data unless data.is_a?(Hash)

        filtered = {}
        data.each do |key, value|
          if sensitive_key?(key)
            filtered[key] = '[FILTERED]'
          elsif value.is_a?(Hash)
            filtered[key] = filter_sensitive_data(value)
          elsif value.is_a?(Array)
            filtered[key] = value.map { |v| v.is_a?(Hash) ? filter_sensitive_data(v) : v }
          else
            filtered[key] = value
          end
        end

        filtered
      end

      def self.sensitive_key?(key)
        key_str = key.to_s.downcase
        %w[password passwd secret token api_key private_key auth credit_card cvv ssn].any? do |sensitive|
          key_str.include?(sensitive)
        end
      end
    end
  end
end
