# frozen_string_literal: true

module Sentry
  module Rails23
    module Breadcrumbs
      class << self
        def activate!
          activate_controller_breadcrumbs!
          activate_activerecord_breadcrumbs!
          activate_logger_breadcrumbs!
          activate_cache_breadcrumbs! if defined?(Rails.cache)
        end

        private

        def activate_controller_breadcrumbs!
          ActionController::Base.class_eval do
            # Use around_filter for timing
            around_filter :capture_controller_breadcrumb

            private

            def capture_controller_breadcrumb
              start_time = Time.now

              # Start breadcrumb
              breadcrumb = Sentry::Breadcrumb.new(
                message: "Processing #{self.class.name}##{action_name}",
                category: 'rails.controller',
                level: :info,
                data: {
                  controller: self.class.name,
                  action: action_name,
                  params: filtered_params_for_breadcrumb,
                  format: request.format.to_s,
                  method: request.request_method
                }
              )
              Sentry.add_breadcrumb(breadcrumb)

              begin
                yield # Execute the action

                # Success breadcrumb
                duration = ((Time.now - start_time) * 1000).round(2)
                breadcrumb = Sentry::Breadcrumb.new(
                  message: "Completed #{self.class.name}##{action_name} (#{response.status || 200})",
                  category: 'rails.controller',
                  level: :info,
                  data: {
                    controller: self.class.name,
                    action: action_name,
                    status: response.status || 200,
                    duration_ms: duration
                  }
                )
                Sentry.add_breadcrumb(breadcrumb)
              rescue => e
                # Error breadcrumb
                duration = ((Time.now - start_time) * 1000).round(2)
                breadcrumb = Sentry::Breadcrumb.new(
                  message: "Failed #{self.class.name}##{action_name}: #{e.class.name}",
                  category: 'rails.controller',
                  level: :error,
                  data: {
                    controller: self.class.name,
                    action: action_name,
                    exception: e.class.name,
                    message: e.message,
                    duration_ms: duration
                  }
                )
                Sentry.add_breadcrumb(breadcrumb)
                raise # Re-raise the exception
              end
            end

            def filtered_params_for_breadcrumb
              return {} unless params

              # Use Rails 2.3 parameter filtering if available
              if respond_to?(:filter_parameters)
                filter_parameters(params.dup)
              else
                # Manual filtering for sensitive keys
                filter_breadcrumb_params(params)
              end
            end

            def filter_breadcrumb_params(params_hash)
              return {} unless params_hash.is_a?(Hash)

              filtered = {}
              sensitive = %w[password secret token api_key auth credit_card]

              params_hash.each do |key, value|
                if sensitive.any? { |s| key.to_s.downcase.include?(s) }
                  filtered[key] = '[FILTERED]'
                elsif value.is_a?(Hash)
                  filtered[key] = filter_breadcrumb_params(value)
                else
                  filtered[key] = value
                end
              end

              filtered
            end
          end
        end

        def activate_activerecord_breadcrumbs!
          # Skip if already activated
          return if ActiveRecord::Base.respond_to?(:find_without_breadcrumb)

          ActiveRecord::Base.class_eval do
            # Hook into CRUD operations
            class << self
              alias_method :create_without_breadcrumb, :create

              def create(attributes = nil, &block)
                result = create_without_breadcrumb(attributes, &block)

                if result && result.valid?
                  breadcrumb = Sentry::Breadcrumb.new(
                    message: "Created #{name} (ID: #{result.id})",
                    category: 'activerecord',
                    level: :info,
                    data: { model: name, id: result.id }
                  )
                  Sentry.add_breadcrumb(breadcrumb)
                end

                result
              end

              alias_method :find_without_breadcrumb, :find

              def find(*args)
                start_time = Time.now
                result = find_without_breadcrumb(*args)
                duration = ((Time.now - start_time) * 1000).round(2)

                # Only log slow queries
                if duration > 100
                  count = result.is_a?(Array) ? result.size : 1
                  breadcrumb = Sentry::Breadcrumb.new(
                    message: "Found #{count} #{name} record(s) (slow: #{duration}ms)",
                    category: 'activerecord',
                    level: :warning,
                    data: { model: name, count: count, duration_ms: duration }
                  )
                  Sentry.add_breadcrumb(breadcrumb)
                end

                result
              rescue => e
                breadcrumb = Sentry::Breadcrumb.new(
                  message: "Failed to find #{name}: #{e.message}",
                  category: 'activerecord',
                  level: :error,
                  data: { model: name, error: e.class.name }
                )
                Sentry.add_breadcrumb(breadcrumb)
                raise
              end
            end

            # Instance method hooks
            alias_method :update_attributes_without_breadcrumb, :update_attributes

            def update_attributes(attributes)
              result = update_attributes_without_breadcrumb(attributes)

              if result
                breadcrumb = Sentry::Breadcrumb.new(
                  message: "Updated #{self.class.name} (ID: #{id})",
                  category: 'activerecord',
                  level: :info,
                  data: {
                    model: self.class.name,
                    id: id,
                    updated_attributes: attributes.keys
                  }
                )
                Sentry.add_breadcrumb(breadcrumb)
              end

              result
            end

            alias_method :destroy_without_breadcrumb, :destroy

            def destroy
              model_name = self.class.name
              model_id = id

              result = destroy_without_breadcrumb

              breadcrumb = Sentry::Breadcrumb.new(
                message: "Destroyed #{model_name} (ID: #{model_id})",
                category: 'activerecord',
                level: :info,
                data: { model: model_name, id: model_id }
              )
              Sentry.add_breadcrumb(breadcrumb)

              result
            end
          end
        end

        def activate_logger_breadcrumbs!
          # Hook into Rails logger
          logger = if defined?(Rails.logger) && Rails.logger
                     Rails.logger
                   elsif defined?(RAILS_DEFAULT_LOGGER)
                     RAILS_DEFAULT_LOGGER
                   end

          if logger && !logger.respond_to?(:add_without_breadcrumb)
            logger.class.class_eval do
              alias_method :add_without_breadcrumb, :add

              def add_with_breadcrumb(severity, message = nil, progname = nil, &block)
                result = add_without_breadcrumb(severity, message, progname, &block)

                # Only capture warnings and above
                if severity && severity >= 2 # WARN level
                  msg = message || (block && block.call) || progname

                  # Skip Rails internal messages
                  unless msg.to_s =~ /^(Processing|Parameters:|Completed|Rendering|Redirected)/

                    level = case severity
                            when 0, 1 then :info
                            when 2 then :warning
                            when 3 then :error
                            else :fatal
                            end

                    breadcrumb = Sentry::Breadcrumb.new(
                      message: msg.to_s[0..200], # Truncate long messages
                      category: 'rails.log',
                      level: level,
                      data: { severity: severity }
                    )
                    Sentry.add_breadcrumb(breadcrumb)
                  end
                end

                result
              end

              alias_method :add, :add_with_breadcrumb
            end
          end
        end

        def activate_cache_breadcrumbs!
          Rails.cache.class.class_eval do
            # Hook cache operations
            [:read, :write, :delete, :exist?].each do |method|
              alias_method "#{method}_without_breadcrumb", method

              define_method "#{method}_with_breadcrumb" do |*args|
                key = args.first
                start_time = Time.now

                result = send("#{method}_without_breadcrumb", *args)

                duration = ((Time.now - start_time) * 1000).round(2)

                # Only log slow cache operations
                if duration > 50
                  operation = method.to_s.upcase
                  hit_miss = (method == :read) ? (result ? 'HIT' : 'MISS') : nil

                  message = "Cache #{operation}: #{key}"
                  message += " (#{hit_miss})" if hit_miss

                  breadcrumb_data = {
                    operation: operation,
                    key: key.to_s,
                    duration_ms: duration
                  }
                  breadcrumb_data[:hit] = (hit_miss == 'HIT') if hit_miss

                  breadcrumb = Sentry::Breadcrumb.new(
                    message: message,
                    category: 'cache',
                    level: duration > 100 ? :warning : :info,
                    data: breadcrumb_data
                  )
                  Sentry.add_breadcrumb(breadcrumb)
                end

                result
              end

              alias_method method, "#{method}_with_breadcrumb"
            end
          end
        end
      end
    end
  end
end