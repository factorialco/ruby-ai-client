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
      end

      sig { override.returns(T::Array[String]) }
      def agent_names
        %w[test_agent another_agent custom_agent]
      end

      sig do
        override
          .params(
            agent_name: String,
            messages: T::Array[Ai::Message],
            runtime_context: T::Hash[String, T.anything],
            max_retries: Integer,
            max_steps: Integer
          )
          .returns(T::Hash[String, T.anything])
      end
      def generate_agent_text(
        agent_name,
        messages:,
        runtime_context: {},
        max_retries: 2,
        max_steps: 5
      )
        # Use the first message content for testing purposes
        message_content = messages.first&.content || ''

        {
          text: message_content,
          files: [],
          reasoning: nil,
          reasoning_details: [],
          sources: [],
          experimental_output: nil,
          tool_calls: [],
          tool_results: [],
          finish_reason: :stop,
          usage: {
            prompt_tokens: 0,
            completion_tokens: 0,
            total_tokens: 0
          },
          warnings: nil,
          steps: [],
          request: {
            body: nil
          },
          response: {
            id: '123',
            timestamp: Time.now,
            model_id: agent_name,
            headers: nil,
            body: nil
          },
          logprobs: nil,
          provider_metadata: nil,
          experimental_provider_metadata: nil
        }
      end

      sig do
        override
          .params(
            agent_name: String,
            messages: T::Array[Ai::Message],
            output: T::Hash[String, T.anything],
            runtime_context: T::Hash[String, T.anything],
            max_retries: Integer,
            max_steps: Integer
          )
          .returns(T::Hash[String, T.anything])
      end
      def generate_agent_object(
        agent_name,
        messages:,
        output:,
        runtime_context: {},
        max_retries: 2,
        max_steps: 5
      )
        {}
      end
    end
  end
end
