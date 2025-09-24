# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task default: :spec

desc "Run tests with coverage"
task :coverage do
  ENV['COVERAGE'] = 'true'
  Rake::Task['spec'].invoke
end

desc "Open a console with the gem loaded"
task :console do
  require 'bundler/setup'
  require 'sentry-rails23'
  require 'irb'
  ARGV.clear
  IRb.start
end