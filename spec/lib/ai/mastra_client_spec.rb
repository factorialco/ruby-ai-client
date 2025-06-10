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
  end
end
