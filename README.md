# Sentry-Rails23

A clean, focused Sentry integration specifically for Rails 2.3 LTS applications.

## Features

- **Full exception tracking** with Rails 2.3 context
- **Comprehensive breadcrumbs** for debugging:
  - Controller actions with timing
  - ActiveRecord operations
  - Cache operations
  - Logger messages
- **Automatic context extraction**:
  - User context from `current_user`
  - Request parameters (filtered)
  - Session data (filtered)
  - HTTP headers
- **Zero configuration** - works out of the box
- **Ruby 3.x compatible** with Rails 2.3 LTS

## Installation

Add to your Gemfile:

```ruby
gem 'sentry-rails23'
```

## Usage

### Basic Setup

In `config/initializers/sentry.rb`:

```ruby
require 'sentry-rails23'

Sentry::Rails23.init(
  dsn: 'YOUR_DSN_HERE',
  environment: Rails.env,
  # Optional: control which environments report to Sentry
  enabled_environments: %w[production staging]
)
```

That's it! Sentry will now:
- Capture all unhandled exceptions
- Add breadcrumbs for debugging
- Extract user and request context
- Filter sensitive parameters

### Advanced Configuration

```ruby
Sentry::Rails23.init do |config|
  config.dsn = 'YOUR_DSN_HERE'
  config.environment = Rails.env
  config.release = "my-app@#{VERSION}"

  # Sampling
  config.sample_rate = 0.5 # Only send 50% of events
  config.traces_sample_rate = 0.1 # 10% of requests for performance

  # Filtering
  config.before_send = lambda do |event, hint|
    # Modify or filter events before sending
    event
  end
end
```

### Manual Exception Capture

```ruby
begin
  dangerous_operation
rescue => e
  Sentry::Rails23.capture_exception(e)
  # Handle the error your way
end
```

### Adding Custom Context

```ruby
class ApplicationController < ActionController::Base
  before_filter :set_sentry_context

  private

  def set_sentry_context
    Sentry.set_user(
      id: current_user.id,
      email: current_user.email,
      subscription: current_user.subscription_type
    )

    Sentry.set_tags(
      feature_flags: current_user.feature_flags,
      tenant: current_tenant.name
    )
  end
end
```

### Custom Breadcrumbs

```ruby
# Add custom breadcrumbs for important events
Sentry.add_breadcrumb(
  message: "User upgraded subscription",
  category: "business",
  level: :info,
  data: {
    from_plan: old_plan,
    to_plan: new_plan,
    amount: upgrade_amount
  }
)
```

## What Gets Captured Automatically

### Context
- User information (id, email, username)
- HTTP request (URL, method, headers, IP)
- Rails parameters (with sensitive data filtered)
- Session data (with sensitive data filtered)
- Controller and action names

### Breadcrumbs
- Controller actions (start/complete with timing)
- ActiveRecord operations (create, update, delete, slow queries)
- Cache operations (read/write/delete with hit/miss)
- Logger warnings and errors
- HTTP requests (if using Net::HTTP)

### Filtered Parameters
These parameters are automatically filtered:
- password, passwd
- secret, token
- api_key, private_key
- auth, authorization
- credit_card, cvv, ssn

## Development

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Console for testing
bundle console
```

## Requirements

- Rails 2.3 LTS (makandra fork)
- Ruby 2.3+ (Ruby 3.x supported with ruby3-backward-compatibility gem)
- sentry-ruby ~> 5.0

## License

MIT