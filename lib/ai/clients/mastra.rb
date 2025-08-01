# typed: strict

require 'net/http'
require 'json'
require 'uri'
require 'securerandom'

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

      sig do
        override
          .params(workflow_name: String, input: T::Struct)
          .returns(T::Hash[T.untyped, T.untyped])
      end
      def run_workflow(workflow_name, input:)
        run_id = SecureRandom.uuid

        # Step 1: Create a new run for the workflow
        create_url =
          URI.join(@endpoint, "api/workflows/#{workflow_name}/create-run?runId=#{run_id}")
        create_response = http_post(create_url)

        unless create_response.is_a?(Net::HTTPSuccess)
          raise Ai::Error, "Mastra error – could not create workflow run: #{create_response.body}"
        end

        # Step 2: Stream the workflow – we only need to consume the stream so that we know when it finishes
        stream_url = URI.join(@endpoint, "api/workflows/#{workflow_name}/stream?runId=#{run_id}")
        stream_request_body = { inputData: JSON.parse(input.to_json), runtimeContext: {} }.to_json
        stream_response =
          http_post(stream_url, body: stream_request_body, stream: true) do |response|
            response.read_body do |_chunk|
              # Intentionally ignore the streaming chunks – we only need to block until the stream ends
            end
          end

        unless stream_response.is_a?(Net::HTTPSuccess)
          raise Ai::Error, "Mastra error – streaming workflow failed: #{stream_response.body}"
        end

        # Step 3: Fetch the execution result once the stream completes
        result_url =
          URI.join(@endpoint, "api/workflows/#{workflow_name}/runs/#{run_id}/execution-result")
        result_http = Net::HTTP.new(result_url.host, result_url.port)
        result_http.use_ssl = (result_url.scheme == 'https')
        result_request = Net::HTTP::Get.new(result_url)
        result_request['Origin'] = Ai.config.origin
        result_response = result_http.request(result_request)

        unless result_response.is_a?(Net::HTTPSuccess)
          raise Ai::Error,
                "Mastra error – could not fetch execution result: #{result_response.body}"
        end

        JSON.parse(result_response.body)['result']
      rescue SocketError
        raise Ai::Error, "Could not resolve endpoint: #{create_url}"
      rescue Timeout::Error
        raise Ai::Error, 'Timeout while connecting to Mastra service'
      end

      sig { override.params(workflow_name: String).returns(T::Hash[String, T.untyped]) }
      def get_workflow(workflow_name)
        url = URI.join(@endpoint, "api/workflows/#{workflow_name}")

        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = (url.scheme == 'https')

        request = Net::HTTP::Get.new(url)
        request['Origin'] = Ai.config.origin

        response = http.request(request)

        unless response.is_a?(Net::HTTPSuccess)
          raise Ai::Error, "Mastra error – could not fetch workflow: #{response.body}"
        end

        JSON.parse(response.body).deep_transform_keys(&:underscore)
      rescue SocketError
        raise Ai::Error, "Could not resolve endpoint: #{url}"
      rescue Timeout::Error
        raise Ai::Error, 'Timeout while connecting to Mastra service'
      end

      private

      sig do
        params(
          url: URI::Generic,
          body: T.nilable(String),
          stream: T::Boolean,
          blk: T.nilable(T.proc.params(response: Net::HTTPResponse).void)
        ).returns(Net::HTTPResponse)
      end
      def http_post(url, body: nil, stream: false, &blk)
        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = (url.scheme == 'https')
        request = Net::HTTP::Post.new(url)
        request['Content-Type'] = 'application/json'
        request['Origin'] = Ai.config.origin
        request.body = body if body

        if stream && blk
          http.request(request, &blk)
        else
          http.request(request)
        end
      end

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
