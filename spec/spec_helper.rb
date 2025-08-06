# typed: strict

require 'rspec/sorbet'
require 'vcr'
require 'webmock/rspec'
require 'ai'

VCR.configure do |config|
  config.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  config.hook_into :webmock
  config.configure_rspec_metadata!

  # Mastra includes in workflow-related URLs (both as a query parameter and as
  # part of the path under `/runs/:uuid`).
  config.register_request_matcher :mastra_uri do |request1, request2|
    scrub =
      lambda do |uri|
        uri.gsub(/runId=[0-9a-f\-]{36}/, 'runId=__IGNORED__') # query param
          .gsub(%r{(/runs/)[0-9a-f\-]{36}}, '\1__IGNORED__') # path segment
      end

    scrub.call(request1.uri) == scrub.call(request2.uri)
  end

  config.default_cassette_options = { match_requests_on: %i[method mastra_uri] }
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
