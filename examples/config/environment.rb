# Rails 2.3 environment file
require File.join(File.dirname(__FILE__), 'boot')

Rails::Initializer.run do |config|
  # Skip frameworks we don't need
  config.frameworks -= [:active_resource, :action_mailer]

  # Session configuration
  config.action_controller.session = {
    :key => '_example_session',
    :secret => 'example_secret_key_for_testing_must_be_at_least_30_characters'
  }

  # Time zone
  config.time_zone = 'UTC'
end