# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

# Load custom rake tasks
Dir[File.join(__dir__, 'lib', 'tasks', '*.rake')].each { |f| load f }

task default: %i[spec]
