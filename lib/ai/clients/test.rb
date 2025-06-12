# typed: strict

require 'net/http'
require 'json'
require 'uri'

module Ai
  module Clients
    class Test < Ai::Client
      extend T::Sig

      sig { params(endpoint: String).void }
      def initialize(endpoint = Ai.config.endpoint)
        @endpoint = endpoint
        @returned_object = T.let({}, T::Hash[String, T.untyped])
      end

      sig { override.returns(T::Array[String]) }
      def agent_names
        %w[test_agent another_agent custom_agent]
      end

      sig { params(output: T::Hash[String, T.untyped]).void }
      def set_returned_object(output) # rubocop:disable Naming/AccessorMethodName
        @returned_object = output
      end

      sig do
        override
          .params(
            agent_name: String,
            messages: T::Array[Ai::Message],
            options: T::Hash[Symbol, T.anything]
          )
          .returns(T::Hash[String, T.anything])
      end
      def generate(agent_name, messages:, options: {})
        output = options[:output] || options[:experimental_output]

        # Use the first message content for testing purposes
        message_content = messages.first&.content || ''

        if output
          # Return object generation format
          {
            'object' => @returned_object,
            'finish_reason' => 'stop',
            'usage' => {
              'prompt_tokens' => 0,
              'completion_tokens' => 0,
              'total_tokens' => 0
            },
            'warnings' => nil,
            'request' => {
              'body' => nil
            },
            'response' => {
              'id' => '123',
              'timestamp' => Time.now,
              'model_id' => agent_name,
              'headers' => nil,
              'body' => ''
            },
            'logprobs' => nil,
            'provider_metadata' => nil,
            'experimental_provider_metadata' => nil
          }
        else
          # Return text generation format
          {
            'text' => message_content,
            'files' => [],
            'reasoning' => nil,
            'reasoning_details' => [],
            'sources' => [],
            'experimental_output' => nil,
            'tool_calls' => [],
            'tool_results' => [],
            'finish_reason' => 'stop',
            'usage' => {
              'prompt_tokens' => 0,
              'completion_tokens' => 0,
              'total_tokens' => 0
            },
            'warnings' => nil,
            'steps' => [],
            'request' => {
              'body' => nil
            },
            'response' => {
              'id' => '123',
              'timestamp' => Time.now,
              'model_id' => agent_name,
              'headers' => nil,
              'body' => ''
            },
            'logprobs' => nil,
            'provider_metadata' => nil,
            'experimental_provider_metadata' => nil
          }
        end
      end
    end
  end
end
