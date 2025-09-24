# Settings specified here will take precedence over those in config/environment.rb

# The test environment is used exclusively to run your application's
# test suite. You never need to work with it otherwise.
config.cache_classes = true

# Log error messages when you accidentally call methods on nil.
config.whiny_nils = true

# Show full error reports and disable caching
config.action_controller.consider_all_requests_local = true
config.action_controller.perform_caching = false

# Disable request forgery protection in test environment
config.action_controller.allow_forgery_protection = false

# Tell Action Mailer not to deliver emails to the real world.
# config.action_mailer.delivery_method = :test

# Use SQL instead of Active Record's schema dumper when creating the test database.
config.active_record.schema_format = :sql