# typed: strict

RSpec.describe Ai::Agent do
  let(:agent) { Ai::Agent.new(agent_name:, client: client) }
  let(:agent_name) { 'test' }
  let(:client) { Ai::Clients::Test.new }

  before { Ai.client = client }

  describe '#generate_text' do
    it 'can generate text with basic message' do
      result = agent.generate_text(messages: [Ai.user_message('Hello, world!')])
      expect(result.text).to eq('Hello, world!')
      expect(result.finish_reason).to eq(:stop)
      expect(result.total_usage.input_tokens).to eq(8)
      expect(result.total_usage.output_tokens).to eq(3)
      expect(result.total_usage.total_tokens).to eq(11)
    end

    it 'passes runtime_context to the client' do
      runtime_context = { 'user_id' => '123', 'session_id' => 'abc' }

      expect(client).to receive(:generate).with(
        'test',
        messages: anything,
        options: {
          runtime_context: runtime_context,
          max_retries: 2,
          max_steps: 5,
          telemetry: anything
        }
      ).and_call_original

      agent.generate_text(messages: [Ai.user_message('Hello')], runtime_context: runtime_context)
    end

    it 'passes custom max_retries and max_steps to client' do
      expect(client).to receive(:generate).with(
        'test',
        messages: anything,
        options: {
          runtime_context: {
          },
          max_retries: 5,
          max_steps: 10,
          telemetry: anything
        }
      ).and_call_original

      agent.generate_text(messages: [Ai.user_message('Hello')], max_retries: 5, max_steps: 10)
    end

    it 'passes telemetry settings to client' do
      telemetry_settings =
        Ai::TelemetrySettings.new(
          enabled: true,
          record_inputs: true,
          record_outputs: true,
          function_id: 'test-function',
          metadata: {
            'agent.name' => 'test-agent'
          }
        )

      expect(client).to receive(:generate).with(
        'test',
        messages: anything,
        options: {
          runtime_context: {
          },
          max_retries: 2,
          max_steps: 5,
          telemetry: telemetry_settings
        }
      ).and_call_original

      agent.generate_text(messages: [Ai.user_message('Hello')], telemetry: telemetry_settings)
    end

    it 'uses default telemetry settings when none provided' do
      expect(client).to receive(:generate).with(
        'test',
        messages: anything,
        options: {
          runtime_context: {
          },
          max_retries: 2,
          max_steps: 5,
          telemetry: kind_of(Ai::TelemetrySettings)
        }
      ).and_call_original

      result = agent.generate_text(messages: [Ai.user_message('Hello')])
      expect(result).to be_a(Ai::GenerateTextResult)
    end

    it 'returns proper response structure' do
      result = agent.generate_text(messages: [Ai.user_message('Hello')])

      expect(result).to respond_to(:text)
      expect(result).to respond_to(:files)
      expect(result).to respond_to(:reasoning)
      expect(result).to respond_to(:finish_reason)
      expect(result).to respond_to(:total_usage)
      expect(result).to respond_to(:steps)
      expect(result).to respond_to(:tool_calls)
      expect(result).to respond_to(:tool_results)

      expect(result.files).to eq([])
      expect(result.tool_calls).to eq([])
      expect(result.tool_results).to eq([])
      expect(result.steps).to eq([])
    end
  end

  describe '#generate_object' do
    subject do
      agent.generate_object(messages: [Ai.user_message('Create person')], output_class: schema)
    end

    let(:schema) do
      Class.new(T::Struct) do
        const :name, String
        const :age, Integer
      end
    end

    before { client.set_returned_object({ 'name' => 'John Doe', 'age' => 30 }) }

    it 'can generate object with valid schema' do
      result = subject

      expect(result.object.name).to eq('John Doe')
      expect(result.object.age).to eq(30)
      expect(result.finish_reason).to eq(:stop)
      expect(result.total_usage.input_tokens).to eq(10)
      expect(result.total_usage.output_tokens).to eq(5)
      expect(result.total_usage.total_tokens).to eq(15)
      expect(result.total_usage.reasoning_tokens).to be_nil
      expect(result.total_usage.cached_input_tokens).to be_nil
    end

    it 'passes runtime_context and options to client' do
      runtime_context = { 'user_id' => '456', 'context' => 'test' }

      expect(client).to receive(:generate).with(
        'test',
        messages: anything,
        options:
          hash_including(
            runtime_context: runtime_context,
            max_retries: 3,
            max_steps: 8,
            structured_output: hash_including(schema: anything),
            telemetry: anything
          )
      ).and_call_original

      agent.generate_object(
        messages: [Ai.user_message('Create person')],
        output_class: schema,
        runtime_context: runtime_context,
        max_retries: 3,
        max_steps: 8
      )
    end

    it 'passes telemetry settings for object generation' do
      telemetry_settings =
        Ai::TelemetrySettings.new(
          enabled: true,
          record_inputs: false,
          record_outputs: true,
          function_id: 'object-generation',
          metadata: {
            'output.type' => 'Person'
          }
        )

      expect(client).to receive(:generate).with(
        'test',
        messages: anything,
        options:
          hash_including(
            telemetry: telemetry_settings,
            structured_output: hash_including(schema: anything)
          )
      ).and_call_original

      agent.generate_object(
        messages: [Ai.user_message('Create person')],
        output_class: schema,
        telemetry: telemetry_settings
      )
    end

    it 'returns proper GenerateObjectResult structure' do
      result = subject

      expect(result).to respond_to(:object)
      expect(result).to respond_to(:finish_reason)
      expect(result).to respond_to(:total_usage)
      expect(result).to respond_to(:warnings)
      expect(result).to respond_to(:request)
      expect(result).to respond_to(:response)
      expect(result).to respond_to(:logprobs)
      expect(result).to respond_to(:provider_metadata)
      expect(result).to respond_to(:experimental_provider_metadata)

      expect(result.object).to be_a(schema)
    end

    context 'when LLM produces a different schema' do
      before { client.set_returned_object({ 'last_name' => 'Bob', 'age' => '42' }) }

      it 'handles type coercion correctly' do
        expect { subject }.to raise_error(ArgumentError)
      end
    end
  end
end
