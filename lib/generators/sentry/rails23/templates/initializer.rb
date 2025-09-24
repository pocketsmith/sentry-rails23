# frozen_string_literal: true

# Sentry error tracking for Rails 2.3
require 'sentry-rails23'

Sentry::Rails23.init do |config|
  # Your Sentry DSN (get this from your Sentry project settings)
  config.dsn = ENV['SENTRY_DSN'] || 'YOUR_DSN_HERE'

  # Environment name
  config.environment = Rails.env

  # Only report errors in these environments
  config.enabled_environments = %w[production staging]

  # Release tracking (optional)
  # config.release = "my-app@#{APP_VERSION}"

  # Performance monitoring (optional, set to nil to disable)
  config.traces_sample_rate = Rails.env.production? ? 0.1 : nil

  # Error sampling (1.0 = 100% of errors are sent)
  config.sample_rate = 1.0

  # Breadcrumb configuration
  config.breadcrumbs_logger = [:sentry_logger, :http_logger]

  # Before sending an event to Sentry
  config.before_send = lambda do |event, hint|
    # You can modify the event here or return nil to not send it
    # For example, filter out certain exceptions:
    #
    # if hint[:exception].is_a?(ActiveRecord::RecordNotFound)
    #   nil  # Don't send 404s to Sentry
    # else
    #   event
    # end

    event
  end

  # Scrub sensitive data from events
  config.before_breadcrumb = lambda do |breadcrumb, hint|
    # Modify breadcrumbs before they're added
    # For example, redact SQL queries containing sensitive data:
    #
    # if breadcrumb.category == 'sql.active_record'
    #   breadcrumb.data[:sql] = breadcrumb.data[:sql].gsub(/\d{4}-\d{4}-\d{4}-\d{4}/, '[REDACTED]')
    # end

    breadcrumb
  end
end

# Optional: Configure Rails 2.3 specific behavior
Sentry::Rails23.configure do |config|
  # Report exceptions that are rescued by Rails (default: true)
  config.report_rescued_exceptions = true
end