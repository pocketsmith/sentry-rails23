# frozen_string_literal: true

module Sentry
  module Rails23
    # Configuration specific to Rails 2.3
    class Configuration
      attr_accessor :environments, :report_rescued_exceptions

      def initialize
        # Defaults
        @environments = %w[production staging]
        @report_rescued_exceptions = true
      end

      # Check if Sentry should be enabled in current environment
      def enabled?
        environments.include?(Rails23.rails_env)
      end
    end

    # Make configuration accessible
    class << self
      def configuration
        @configuration ||= Configuration.new
      end

      def configure
        yield configuration if block_given?
      end
    end
  end
end