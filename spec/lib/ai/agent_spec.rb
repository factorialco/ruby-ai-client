# typed: strict

RSpec.describe Ai::Agent do
  let(:client) { Ai::Clients::Test.new }

  before { Ai.client = client }

  describe '.generate_text' do
    it 'can generate text with basic message' do
      result = Ai::Agent.generate_text('test', messages: [Ai.user_message('Hello, world!')])
      expect(result.text).to eq('Hello, world!')
      expect(result.finish_reason).to eq(:stop)
      expect(result.usage.prompt_tokens).to eq(0)
      expect(result.usage.completion_tokens).to eq(0)
      expect(result.usage.total_tokens).to eq(0)
    end

    it 'passes runtime_context to the client' do
      runtime_context = { 'user_id' => '123', 'session_id' => 'abc' }

      expect(client).to receive(:generate_agent_text).with(
        'test',
        messages: anything,
        runtime_context: runtime_context,
        max_retries: 2,
        max_steps: 5
      ).and_call_original

      Ai::Agent.generate_text(
        'test',
        messages: [Ai.user_message('Hello')],
        runtime_context: runtime_context
      )
    end

    it 'passes custom max_retries and max_steps to client' do
      expect(client).to receive(:generate_agent_text).with(
        'test',
        messages: anything,
        runtime_context: {
        },
        max_retries: 5,
        max_steps: 10
      ).and_call_original

      Ai::Agent.generate_text(
        'test',
        messages: [Ai.user_message('Hello')],
        max_retries: 5,
        max_steps: 10
      )
    end

    it 'handles different agent names' do
      result = Ai::Agent.generate_text('custom_agent', messages: [Ai.user_message('Test')])
      expect(result.text).to eq('Test')
    end

    it 'returns proper response structure' do
      result = Ai::Agent.generate_text('test', messages: [Ai.user_message('Hello')])

      expect(result).to respond_to(:text)
      expect(result).to respond_to(:files)
      expect(result).to respond_to(:reasoning)
      expect(result).to respond_to(:finish_reason)
      expect(result).to respond_to(:usage)
      expect(result).to respond_to(:steps)
      expect(result).to respond_to(:tool_calls)
      expect(result).to respond_to(:tool_results)

      expect(result.files).to eq([])
      expect(result.tool_calls).to eq([])
      expect(result.tool_results).to eq([])
      expect(result.steps).to eq([])
    end
  end

  describe 'Agent.[]' do
    class Output < T::Struct
      const :name, String
      const :age, Integer
    end

    it 'creates an agent instance with output class' do
      agent = Ai::Agent['test_agent', Output]

      expect(agent.agent_name).to eq('test_agent')
      expect(agent.output_class).to eq(Output)
      expect(agent.client).to eq(client)
    end

    it 'instantiates response as output struct' do
      agent = Ai::Agent['test_agent', Output]

      allow(client).to receive(:generate_agent_object).and_return(
        mock_object_response({ 'name' => 'John', 'age' => 30 })
      )

      result = agent.generate_object(messages: [Ai.user_message('Test')])

      expect(result.object).to be_a(Output)
      expect(result.object.name).to eq('John')
      expect(result.object.age).to eq(30)
    end

    it 'raises error when calling generate_object without output_class' do
      agent = Ai::Agent::Instance.new(agent_name: 'test', client: client, output_class: nil)

      expect { agent.generate_object(messages: [Ai.user_message('Test')]) }.to raise_error(
        /You need to provide an output class/
      )
    end
  end

  describe 'mocked responses' do
    context 'when client returns different text' do
      before do
        allow(client).to receive(:generate_agent_text).and_return(
          mock_text_response(
            'Mocked response',
            files: [
              mock_file('SGVsbG8gd29ybGQ=', [72, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100]), # "Hello world"
              mock_file('VGVzdCBmaWxlIDI=', [84, 101, 115, 116, 32, 102, 105, 108, 101, 32, 50]) # "Test file 2"
            ],
            reasoning: 'This is my reasoning',
            reasoning_details: [{ type: 'text', text: 'First thought', signature: nil, data: nil }],
            sources: %w[source1 source2],
            experimental_output: {
              custom: 'data'
            },
            tool_calls: [{ name: 'test_tool', args: {} }],
            tool_results: [{ result: 'success' }],
            finish_reason: :tool_calls,
            warnings: ['Warning message'],
            steps: [mock_step('Thinking step', reasoning: 'Step reasoning')],
            request: mock_request('request body'),
            response:
              mock_response_metadata('mock-id-456', 'mock-model', 'response body').merge(
                'timestamp' => Time.new(2023, 1, 1),
                'headers' => {
                  'Content-Type' => 'application/json'
                }
              ),
            logprobs: {
              tokens: %w[hello world]
            },
            provider_metadata: {
              provider: 'test'
            },
            experimental_provider_metadata: {
              experimental: true
            }
          )
        )
      end

      it 'returns the mocked response data' do
        result = Ai::Agent.generate_text('test', messages: [Ai.user_message('Any message')])

        expect(result.text).to eq('Mocked response')
        expect(result.files.length).to eq(2)
        expect(T.must(result.files.first).base64).to eq('SGVsbG8gd29ybGQ=')
        expect(T.must(result.files.first).mime_type).to eq('text/plain')
        expect(T.must(result.files.last).base64).to eq('VGVzdCBmaWxlIDI=')
        expect(result.reasoning).to eq('This is my reasoning')
        expect(result.finish_reason).to eq(:tool_calls)
        expect(result.usage.prompt_tokens).to eq(10)
        expect(result.usage.completion_tokens).to eq(20)
        expect(result.usage.total_tokens).to eq(30)
        expect(result.steps.length).to eq(1)
        expect(T.must(result.steps.first).text).to eq('Thinking step')
        expect(T.must(result.steps.first).step_type).to eq('initial')
        expect(result.tool_calls).to eq([{ name: 'test_tool', args: {} }])
        expect(result.tool_results).to eq([{ result: 'success' }])
      end
    end

    context 'when client simulates an error scenario' do
      before do
        allow(client).to receive(:generate_agent_text).and_return(
          mock_text_response(
            'Error occurred',
            finish_reason: :error,
            usage: mock_usage(5, 0, 5),
            warnings: ['Model encountered an error'],
            response: mock_response_metadata('error-123', 'test', 'error response body')
          )
        )
      end

      it 'handles error responses gracefully' do
        result = Ai::Agent.generate_text('test', messages: [Ai.user_message('Trigger error')])

        expect(result.text).to eq('Error occurred')
        expect(result.finish_reason).to eq(:error)
        expect(result.usage.completion_tokens).to eq(0)
        expect(result.warnings).to eq(['Model encountered an error'])
      end
    end
  end

  private

  def mock_object_response(object_data, options = {})
    {
      'object' => object_data,
      'finish_reason' => options[:finish_reason] || :stop,
      'usage' => options[:usage] || mock_usage,
      'warnings' => options[:warnings],
      'request' => options[:request] || mock_request,
      'response' =>
        options[:response] || mock_response_metadata(options[:response_id] || 'mock-123'),
      'logprobs' => options[:logprobs],
      'provider_metadata' => options[:provider_metadata],
      'experimental_provider_metadata' => options[:experimental_provider_metadata]
    }
  end

  def mock_usage(prompt_tokens = 10, completion_tokens = 20, total_tokens = 30)
    {
      'prompt_tokens' => prompt_tokens,
      'completion_tokens' => completion_tokens,
      'total_tokens' => total_tokens
    }
  end

  def mock_request(body = nil)
    { 'body' => body }
  end

  def mock_response_metadata(id = 'mock-123', model = 'test', body = 'mock response body')
    { 'id' => id, 'timestamp' => Time.now, 'model_id' => model, 'headers' => nil, 'body' => body }
  end

  def mock_text_response(text, options = {})
    {
      text: text,
      files: options[:files] || [],
      reasoning: options[:reasoning],
      reasoning_details: options[:reasoning_details] || [],
      sources: options[:sources] || [],
      experimental_output: options[:experimental_output],
      tool_calls: options[:tool_calls] || [],
      tool_results: options[:tool_results] || [],
      finish_reason: options[:finish_reason] || :stop,
      usage: options[:usage] || mock_usage,
      warnings: options[:warnings],
      steps: options[:steps] || [],
      request: options[:request] || mock_request,
      response: options[:response] || mock_response_metadata,
      logprobs: options[:logprobs],
      provider_metadata: options[:provider_metadata],
      experimental_provider_metadata: options[:experimental_provider_metadata]
    }
  end

  def mock_file(base64, uint8_array, mime_type = 'text/plain')
    { base64: base64, uint8_array: uint8_array, mime_type: mime_type }
  end

  def mock_step(text, options = {})
    {
      text: text,
      reasoning: options[:reasoning],
      reasoning_details: options[:reasoning_details] || [],
      files: options[:files] || [],
      sources: options[:sources] || [],
      tool_calls: options[:tool_calls] || [],
      tool_results: options[:tool_results] || [],
      finish_reason: options[:finish_reason] || :stop,
      usage: options[:usage] || mock_usage(1, 1, 2),
      warnings: options[:warnings],
      logprobs: options[:logprobs],
      request: options[:request] || mock_request,
      response:
        options[:response] || mock_response_metadata('step-123', 'test', 'step response body'),
      provider_metadata: options[:provider_metadata],
      experimental_provider_metadata: options[:experimental_provider_metadata],
      step_type: options[:step_type] || 'initial',
      is_continued: options[:is_continued] || false
    }
  end
end
