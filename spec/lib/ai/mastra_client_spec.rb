# typed: strict
# frozen_string_literal: true

RSpec.describe Ai::Clients::Mastra do
  let(:endpoint) { 'https://mastra.local.factorial.dev' }
  let(:client) { described_class.new(endpoint) }

  describe '#generate', :vcr do
    let(:output_schema) do
      {
        'type' => 'object',
        'properties' => {
          'name' => {
            'type' => 'string'
          },
          'age' => {
            'type' => 'integer'
          }
        },
        'required' => %w[name age],
        'additionalProperties' => false
      }
    end

    context 'when the endpoint is blank' do
      it 'raises an error' do
        expect { described_class.new('') }.to raise_error(
          Ai::Error,
          'Mastra endpoint is not set. Please set the MASTRA_LOCATION environment variable or configure the client in the Ai.config object.'
        )
      end
    end

    it 'generates text using the Mastra API' do
      telemetry_settings =
        Ai::TelemetrySettings.new(
          enabled: true,
          record_inputs: true,
          record_outputs: true,
          function_id: 'mastra-text-generation',
          metadata: {
            'agent.name' => 'marvin',
            'service.version' => '1.0.0'
          }
        )

      VCR.use_cassette('mastra_generate_agent_text') do
        result =
          client.generate(
            'marvin',
            messages: [Ai.user_message('Hello!')],
            options: {
              telemetry: telemetry_settings
            }
          )

        expect(result).to be_a(Hash)
        expect(result).to have_key('text')
        expect(result['text']).to eq('Hello! What data or report can I help you retrieve today?')
      end
    end

    it 'generates structured object using the Mastra API' do
      telemetry_settings =
        Ai::TelemetrySettings.new(
          enabled: true,
          record_inputs: false,
          record_outputs: true,
          function_id: 'mastra-object-generation',
          metadata: {
            'agent.name' => 'marvin',
            'output.type' => 'Person'
          }
        )

      VCR.use_cassette('mastra_generate_agent_object') do
        result =
          client.generate(
            'marvin',
            messages: [Ai.user_message('Hello!')],
            options: {
              structured_output: {
                schema: output_schema
              },
              telemetry: telemetry_settings
            }
          )
        expect(result).to be_a(Hash)
        expect(result).to have_key('object')
        expect(result.dig('object', 'name')).to eq('Hello!')
        expect(result.dig('object', 'age')).to eq(0)
      end
    end

    it 'converts struct fields to camelCase' do
      telemetry_settings =
        Ai::TelemetrySettings.new(enabled: false, record_inputs: true, function_id: 'test')

      stub =
        stub_request(:post, 'https://mastra.local.factorial.dev/api/agents/marvin/generate')
          .with do |req|
            body = JSON.parse(req.body)
            body['telemetry'] && body['telemetry']['isEnabled'] == false &&
              body['telemetry']['recordInputs'] == true &&
              body['telemetry']['functionId'] == 'test' && !body['telemetry'].key?('is_enabled') &&
              !body['telemetry'].key?('record_inputs') && !body['telemetry'].key?('function_id')
          end
          .to_return(
            status: 200,
            body: { text: 'Test response' }.to_json,
            headers: {
              'Content-Type' => 'application/json'
            }
          )

      client.generate(
        'marvin',
        messages: [Ai.user_message('test')],
        options: {
          telemetry: telemetry_settings
        }
      )

      expect(stub).to have_been_requested
    end
  end

  describe '#generate with per-request headers' do
    let(:generate_url) { "#{endpoint}/api/agents/marvin/generate" }

    before do
      Ai.config.api_key = 'global-api-key'
      stub_request(:post, generate_url).to_return(
        status: 200,
        body: { text: 'Test response' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    end

    after { Ai.config.api_key = nil }

    it 'sends the given headers alongside the global ones' do
      client.generate(
        'marvin',
        messages: [Ai.user_message('test')],
        headers: {
          'X-Factorial-Actor-Type' => 'Employee',
          'X-Factorial-Actor-Id' => '42'
        }
      )

      expect(WebMock).to have_requested(:post, generate_url).with(
        headers: {
          'Authorization' => 'Bearer global-api-key',
          'X-Factorial-Actor-Type' => 'Employee',
          'X-Factorial-Actor-Id' => '42'
        }
      )
    end

    it 'lets per-request headers override the global configuration' do
      client.generate(
        'marvin',
        messages: [Ai.user_message('test')],
        headers: { 'Authorization' => 'Bearer per-request-token' }
      )

      expect(WebMock).to have_requested(:post, generate_url).with(
        headers: { 'Authorization' => 'Bearer per-request-token' }
      )
    end

    it 'sends only the global headers by default' do
      client.generate('marvin', messages: [Ai.user_message('test')])

      expect(WebMock).to have_requested(:post, generate_url).with(
        headers: { 'Authorization' => 'Bearer global-api-key' }
      )
    end
  end

  describe '#run_workflow with per-request headers' do
    let(:workflow_name) { 'testWorkflow' }
    let(:run_id_pattern) { %r{#{Regexp.escape(endpoint)}/api/workflows/testWorkflow/} }
    let(:input) do
      unnamed_struct = Class.new(T::Struct) { const :first_number, Integer }
      unnamed_struct.new(first_number: 3)
    end

    before do
      Ai.config.api_key = 'global-api-key'
      stub_request(:post, run_id_pattern).to_return(
        status: 200,
        body: '{}',
        headers: { 'Content-Type' => 'application/json' }
      )
      stub_request(:get, run_id_pattern).to_return(
        status: 200,
        body: { status: 'success', result: { 'ok' => true } }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    end

    after { Ai.config.api_key = nil }

    # A workflow run is three requests (create-run, stream, fetch result); the actor
    # must travel on all of them, not just the first.
    it 'sends the given headers on every request of the run' do
      client.run_workflow(
        workflow_name,
        input: input,
        headers: {
          'X-Factorial-Actor-Type' => 'Employee',
          'X-Factorial-Actor-Id' => '42'
        }
      )

      actor_headers = {
        'X-Factorial-Actor-Type' => 'Employee',
        'X-Factorial-Actor-Id' => '42'
      }
      expect(WebMock).to have_requested(:post, %r{/create-run}).with(headers: actor_headers)
      expect(WebMock).to have_requested(:post, %r{/stream}).with(headers: actor_headers)
      expect(WebMock).to have_requested(:get, %r{/runs/}).with(headers: actor_headers)
    end

    it 'lets per-request headers override the global configuration' do
      client.run_workflow(
        workflow_name,
        input: input,
        headers: { 'Authorization' => 'Bearer per-request-token' }
      )

      expect(WebMock).to have_requested(:post, %r{/create-run}).with(
        headers: { 'Authorization' => 'Bearer per-request-token' }
      )
      expect(WebMock).to have_requested(:get, %r{/runs/}).with(
        headers: { 'Authorization' => 'Bearer per-request-token' }
      )
    end

    it 'sends only the global headers by default' do
      client.run_workflow(workflow_name, input: input)

      expect(WebMock).to have_requested(:post, %r{/create-run}).with(
        headers: { 'Authorization' => 'Bearer global-api-key' }
      )
    end
  end

  describe '#deep_camelize_keys' do
    # Regression: `deep_camelize_keys` used to camelize property KEYS but leave the
    # string VALUES in JSON-schema `required` arrays snake_case, producing a schema
    # that OpenAI's strict structured outputs reject. `required` must list every key
    # in `properties`, so it has to be camelized alongside them.

    it 'camelizes `required` values to match the camelized property keys (flat)' do
      options = {
        structured_output: {
          schema: {
            type: 'object',
            properties: {
              matches: {
                type: 'array',
                items: {
                  type: 'object',
                  properties: {
                    transaction_id: { type: 'integer' },
                    category_id: { 'anyOf' => [{ type: 'integer' }, { type: 'null' }] }
                  },
                  required: %w[transaction_id category_id],
                  additionalProperties: false
                }
              }
            },
            required: ['matches'],
            additionalProperties: false
          }
        }
      }

      items =
        client.send(:deep_camelize_keys, options).dig(
          :structuredOutput,
          :schema,
          :properties,
          :matches,
          :items
        )

      aggregate_failures do
        expect(items[:properties].keys).to contain_exactly(:transactionId, :categoryId)
        expect(items[:required]).to eq(%w[transactionId categoryId])
      end
    end

    it 'camelizes `required` inside nested nilable (anyOf) schemas' do
      options = {
        structured_output: {
          schema: {
            type: 'object',
            properties: {
              payment_details: {
                'anyOf' => [
                  {
                    type: 'object',
                    properties: {
                      account_number: { 'anyOf' => [{ type: 'string' }, { type: 'null' }] }
                    },
                    required: %w[account_number],
                    additionalProperties: false
                  },
                  { type: 'null' }
                ]
              }
            },
            required: %w[payment_details],
            additionalProperties: false
          }
        }
      }

      object_branch =
        client.send(:deep_camelize_keys, options).dig(
          :structuredOutput,
          :schema,
          :properties,
          :paymentDetails,
          :anyOf,
          0
        )

      aggregate_failures do
        expect(object_branch[:properties].keys).to contain_exactly(:accountNumber)
        expect(object_branch[:required]).to eq(%w[accountNumber])
      end
    end
  end

  describe '#run_workflow' do
    let(:workflow_name) { 'testWorkflow' }
    let(:input) do
      unnamed_struct =
        Class.new(T::Struct) do
          const :first_number, Integer
          const :second_number, Integer
        end

      unnamed_struct.new(first_number: 3, second_number: 5)
    end

    it 'executes the workflow and returns the summed result' do
      VCR.use_cassette('mastra_workflow_run') do
        result = client.run_workflow(workflow_name, input: input)

        expect(result).to eq('sumOfNumbers' => 8)
      end
    end
  end
end
