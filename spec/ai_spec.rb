# typed: strict

RSpec.describe Ai do
  it 'has a version number' do
    expect(Ai::VERSION).not_to be_nil
  end

  describe 'configuration' do
    after do
      # Reset configuration after each test
      Ai.config.endpoint = nil
      Ai.config.origin = nil
      Ai.config.client = Ai::Clients::Mastra.new
    end

    describe '.endpoint' do
      it 'can be set and retrieved' do
        endpoint = 'https://api.example.com'
        Ai.config.endpoint = endpoint
        expect(Ai.config.endpoint).to eq(endpoint)
      end

      it 'defaults to nil' do
        expect(Ai.config.endpoint).to be_nil
      end
    end

    describe '.origin' do
      it 'can be set and retrieved' do
        origin = 'https://app.example.com'
        Ai.config.origin = origin
        expect(Ai.config.origin).to eq(origin)
      end

      it 'defaults to nil' do
        expect(Ai.config.origin).to be_nil
      end
    end

    describe '.client' do
      it 'can be set and retrieved' do
        test_client = Ai::Clients::Test.new
        Ai.config.client = test_client
        expect(Ai.config.client).to eq(test_client)
      end

      it 'defaults to Mastra client' do
        expect(Ai.config.client).to be_a(Ai::Clients::Mastra)
      end
    end
  end

  describe '.user_message' do
    it 'creates a user message with the given content' do
      content = 'Hello, world!'
      message = Ai.user_message(content)

      expect(message).to be_a(Ai::Message)
      expect(message.role).to eq(Ai::MessageRole::User)
      expect(message.content).to eq(content)
    end

    it 'handles empty content' do
      message = Ai.user_message('')
      expect(message.content).to eq('')
      expect(message.role).to eq(Ai::MessageRole::User)
    end
  end

  describe '.system_message' do
    it 'creates a system message with the given content' do
      content = 'You are a helpful assistant.'
      message = Ai.system_message(content)

      expect(message).to be_a(Ai::Message)
      expect(message.role).to eq(Ai::MessageRole::System)
      expect(message.content).to eq(content)
    end

    it 'handles empty content' do
      message = Ai.system_message('')
      expect(message.content).to eq('')
      expect(message.role).to eq(Ai::MessageRole::System)
    end
  end
end
