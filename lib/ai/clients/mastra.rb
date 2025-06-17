# typed: strict

require 'net/http'
require 'json'
require 'uri'

module Ai
  module Clients
    class Mastra < Ai::Client
      extend T::Sig

      sig { params(endpoint: String).void }
      def initialize(endpoint)
        if endpoint.blank?
          raise Ai::Error,
                'Mastra endpoint is not set. Please set the MASTRA_LOCATION environment variable or configure the client in the Ai.config object.'
        end

        @endpoint = endpoint
      end

      sig { override.returns(T::Array[String]) }
      def agent_names
        url = URI.join(@endpoint, 'api/agents')
        response = Net::HTTP.get(url)
        JSON.parse(response).keys
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
        url = URI.join(@endpoint, "api/agents/#{agent_name}/generate")

        generated_response = response(url: url, messages: messages, options: options)

        JSON.parse(generated_response.body).deep_transform_keys(&:underscore)
      end

      private

      sig do
        params(
          url: URI::Generic,
          messages: T::Array[Ai::Message],
          options: T::Hash[Symbol, T.anything]
        ).returns(Net::HTTPResponse)
      end
      def response(url:, messages:, options:)
        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = (url.scheme == 'https')

        request = Net::HTTP::Post.new(url)
        request['Content-Type'] = 'text/plain;charset=UTF-8'
        request['Origin'] = Ai.config.origin

        # convert to camelCase and unpacking for API compatibility
        camelized_options = options.deep_transform_keys { |key| key.to_s.camelize(:lower).to_sym }
        request.body = { messages: messages, **camelized_options }.to_json

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
