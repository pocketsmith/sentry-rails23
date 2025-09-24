# Rails 2.3 environment file
require File.join(File.dirname(__FILE__), 'boot')

Rails::Initializer.run do |config|
  # Skip frameworks we don't need for testing
  config.frameworks -= [:active_resource, :action_mailer]

  # Session configuration
  config.action_controller.session = {
    :key => '_test_session',
    :secret => 'test_secret_key_for_testing_only_must_be_at_least_30_characters_long'
  }

  # Time zone
  config.time_zone = 'UTC'
end