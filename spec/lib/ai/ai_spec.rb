# typed: strict

RSpec.describe Ai do
  it 'has a version number' do
    expect(Ai::VERSION).not_to be_nil
  end

  describe 'configuration' do
    after do
      # Reset configuration after each test
      Ai.config.origin = nil
      Ai.config.client = nil
    end

    describe '.origin' do
      it 'can be set and retrieved' do
        origin = 'https://app.example.com'
        Ai.config.origin = origin
        expect(Ai.config.origin).to eq(origin)
      end
    end

    describe '.client' do
      it 'can be set and retrieved' do
        test_client = Ai::Clients::Test.new
        Ai.config.client = test_client
        expect(Ai.config.client).to eq(test_client)
      end

      context 'when the MASTRA_LOCATION environment variable is set' do
        before { ENV['MASTRA_LOCATION'] = 'https://mastra_host:4111' }

        it 'uses the Mastra client' do
          expect(Ai.client).to be_a(Ai::Clients::Mastra)
        end
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
