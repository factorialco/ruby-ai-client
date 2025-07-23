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
      VCR.use_cassette('mastra_generate_agent_text') do
        result = client.generate('marvin', messages: [Ai.user_message('Hello!')])

        expect(result).to be_a(Hash)
        expect(result).to have_key('text')
        expect(result['text']).to eq('Hello! What data or report can I help you retrieve today?')
      end
    end

    it 'generates structured object using the Mastra API' do
      VCR.use_cassette('mastra_generate_agent_object') do
        result =
          client.generate(
            'marvin',
            messages: [Ai.user_message('Hello!')],
            options: {
              output: output_schema
            }
          )

        expect(result).to be_a(Hash)
        expect(result).to have_key('object')
        expect(result.dig('object', 'name')).to eq('Hello!')
        expect(result.dig('object', 'age')).to eq(0)
      end
    end

    it 'generates text with telemetry settings using the Mastra API' do
      telemetry_settings = Ai::TelemetrySettings.new(
        is_enabled: true,
        record_inputs: true,
        record_outputs: true,
        function_id: 'test-text-function',
        metadata: { 'agent.name' => 'marvin', 'service.version' => '1.0.0' }
      )

      VCR.use_cassette('mastra_generate_agent_text_with_telemetry') do
        result = client.generate(
          'marvin',
          messages: [Ai.user_message('Hello with telemetry!')],
          options: { telemetry: telemetry_settings }
        )

        expect(result).to be_a(Hash)
        expect(result).to have_key('text')
        expect(result['text']).to be_a(String)
      end
    end

    it 'generates structured object with telemetry settings using the Mastra API' do
      telemetry_settings = Ai::TelemetrySettings.new(
        is_enabled: true,
        record_inputs: false,
        record_outputs: true,
        function_id: 'test-object-function',
        metadata: { 'agent.name' => 'marvin', 'output.type' => 'Person' }
      )

      VCR.use_cassette('mastra_generate_agent_object_with_telemetry') do
        result = client.generate(
          'marvin',
          messages: [Ai.user_message('Create a person with telemetry!')],
          options: {
            output: output_schema,
            telemetry: telemetry_settings
          }
        )

        expect(result).to be_a(Hash)
        expect(result).to have_key('object')
        expect(result.dig('object', 'name')).to be_a(String)
        expect(result.dig('object', 'age')).to be_a(Integer)
      end
    end
  end
end
