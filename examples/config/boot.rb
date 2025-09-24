# Rails 2.3 boot file
RAILS_ROOT = "#{File.dirname(__FILE__)}/.." unless defined?(RAILS_ROOT)

module Rails
  class << self
    def boot!
      unless booted?
        preinitialize
        pick_boot.run
      end
    end

    def booted?
      defined? Rails::Initializer
    end

    def pick_boot
      GemBoot.new
    end

    def vendor_rails?
      false
    end

    def preinitialize
    end
  end

  class Boot
    def run
      load_initializer
      Rails::Initializer.run(:set_load_path)
    end
  end

  class GemBoot < Boot
    def load_initializer
      self.class.load_rubygems
      load_rails_gem
      require 'initializer'
    end

    def load_rails_gem
      gem 'rails'
    rescue Gem::LoadError => load_error
      $stderr.puts %(Missing the Rails gem. Please `gem install rails`.)
      exit 1
    end

    class << self
      def rubygems_version
        Gem::RubyGemsVersion rescue nil
      end

      def load_rubygems
        require 'rubygems'
      rescue LoadError
        $stderr.puts %Q(Rails requires RubyGems. Please install RubyGems and try again: http://rubygems.rubyforge.org)
        exit 1
      end
    end
  end
end

Rails.boot! unless defined?(Rails::Initializer)