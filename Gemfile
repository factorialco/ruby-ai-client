# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in ai.gemspec
gemspec

gem 'rake', '~> 13.0'
gem 'activesupport'
gem 'actionpack'
gem 'railties'
gem 'json_schemer', '~> 2.4'
gem 'sorbet', '0.6.12544'
gem 'sorbet-coerce', '~> 0.7'
gem 'sorbet-static-and-runtime', '0.6.12544'

group :development, :test do
  gem 'rspec'
  gem 'rspec-sorbet', '~> 1.9.2'
  gem 'rubocop', '~> 1.21'
  gem 'rubocop-sorbet', '0.10.0', require: false
  gem 'rubocop-rspec', '3.6.0', require: false
  gem 'rubocop-performance', '1.25.0', require: false
  gem 'byebug'
  gem 'vcr', '~> 6.0'
  gem 'webmock', '~> 3.0'
  gem 'tapioca', '~> 0.17.7', require: false
  gem 'syntax_tree', '~> 6.2', require: false
  gem 'prettier', '~> 3.2.2'
  gem 'ruby_parser'
end
