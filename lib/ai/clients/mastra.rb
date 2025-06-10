# typed: strict

require 'net/http'
require 'json'
require 'uri'

module Ai
  module Clients
    class Mastra < Ai::Client
      extend T::Sig

      sig { params(endpoint: String).void }
      def initialize(endpoint = Ai.config.endpoint)
        @endpoint = endpoint
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
        url = URI.join(@endpoint, "api/agents/#{agent_name}/generate")

        generated_response =
          response(
            url: url,
            messages: messages,
            runtime_context: runtime_context,
            max_retries: max_retries,
            max_steps: max_steps
          )
        JSON.parse(generated_response.body).deep_transform_keys(&:underscore)
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
        uri = URI.join(@endpoint, "api/agents/#{agent_name}/generate")

        generated_response =
          response(
            url: uri,
            messages: messages,
            runtime_context: runtime_context,
            max_retries: max_retries,
            max_steps: max_steps,
            output: output
          )

        JSON.parse(generated_response.body).deep_transform_keys(&:underscore)
      end

      private

      sig do
        params(
          url: URI::Generic,
          messages: T::Array[Ai::Message],
          runtime_context: T::Hash[String, T.anything],
          max_retries: Integer,
          max_steps: Integer,
          output: T.nilable(T::Hash[String, T.anything])
        ).returns(Net::HTTPResponse)
      end
      def response(url:, messages:, runtime_context:, max_retries:, max_steps:, output: nil)
        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = true

        request = Net::HTTP::Post.new(url)
        request['Content-Type'] = 'text/plain;charset=UTF-8'
        request['Origin'] = Ai.config.origin

        request.body = {
          messages: messages,
          maxRetries: max_retries,
          maxSteps: max_steps,
          runtimeContext: runtime_context,
          output: output
        }.to_json

        response = http.request(request)

        unless response.is_a?(Net::HTTPSuccess)
          error =
            begin
              JSON.parse(response.body)['error']
            rescue JSON::ParserError
              "Unknown error: #{response.body}"
            end

          raise Ai::Error, error
        end

        response
      rescue Socket::ResolutionError
        raise Ai::Error, "Could not resolve endpoint: #{url}"
      rescue Timeout::Error
        raise Ai::Error, "Timeout while connecting to #{url}"
      end
    end
  end
end
