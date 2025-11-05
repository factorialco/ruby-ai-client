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

  describe '.user_message_with_image' do
    it 'creates a user message with text and image parts' do
      text = 'What is in this image?'
      image_data = 'binary image data'
      media_type = 'image/png'

      message = Ai.user_message_with_image(text, image_data, media_type)

      expect(message).to be_a(Ai::Message)
      expect(message.role).to eq(Ai::MessageRole::User)
      expect(message.content).to be_an(Array)
      expect(message.content.length).to eq(2)
    end

    it 'creates proper content parts' do
      text = 'Describe this'
      image_data = 'image bytes'
      media_type = 'image/jpeg'

      message = Ai.user_message_with_image(text, image_data, media_type)
      content = message.content

      expect(content[0]).to be_a(Ai::TextPart)
      expect(content[0].text).to eq(text)

      expect(content[1]).to be_a(Ai::ImagePart)
      expect(content[1].image_data).to eq(image_data)
      expect(content[1].media_type).to eq(media_type)
    end

    it 'serializes correctly for API calls' do
      text = 'Analyze this'
      image_data = 'test image'
      media_type = 'image/png'

      message = Ai.user_message_with_image(text, image_data, media_type)
      json = message.as_json

      expect(json[:role]).to eq('user')
      expect(json[:content]).to be_an(Array)
      expect(json[:content][0][:type]).to eq('text')
      expect(json[:content][0][:text]).to eq(text)
      expect(json[:content][1][:type]).to eq('image')
      expect(json[:content][1][:image]).to start_with('data:image/png;base64,')
    end

    it 'handles different image formats' do
      formats = ['image/png', 'image/jpeg', 'image/gif', 'image/webp']

      formats.each do |format|
        message = Ai.user_message_with_image('Test', 'data', format)
        json = message.as_json

        expect(json[:content][1][:mediaType]).to eq(format)
        expect(json[:content][1][:image]).to start_with("data:#{format};base64,")
      end
    end

    it 'properly encodes binary data to base64' do
      # Simulate actual binary data (PNG header bytes)
      binary_data = [137, 80, 78, 71, 13, 10, 26, 10].pack('C*')

      message = Ai.user_message_with_image('What is this?', binary_data, 'image/png')
      json = message.as_json

      # Extract and verify the base64 portion
      base64_data = json[:content][1][:image].gsub('data:image/png;base64,', '')
      decoded = Base64.strict_decode64(base64_data)

      expect(decoded).to eq(binary_data)
    end
  end

  describe '.user_message_with_image_url' do
    it 'creates a user message with text and image URL parts' do
      text = 'What is in this image?'
      image_url = 'https://example.com/photo.jpg'
      media_type = 'image/jpeg'

      message = Ai.user_message_with_image_url(text, image_url, media_type)

      expect(message).to be_a(Ai::Message)
      expect(message.role).to eq(Ai::MessageRole::User)
      expect(message.content).to be_an(Array)
      expect(message.content.length).to eq(2)
    end

    it 'creates proper content parts with URL' do
      text = 'Describe this'
      image_url = 'https://cdn.example.com/image.png'
      media_type = 'image/png'

      message = Ai.user_message_with_image_url(text, image_url, media_type)
      content = message.content

      expect(content[0]).to be_a(Ai::TextPart)
      expect(content[0].text).to eq(text)

      expect(content[1]).to be_a(Ai::ImagePart)
      expect(content[1].image_url).to eq(image_url)
      expect(content[1].image_data).to be_nil
      expect(content[1].media_type).to eq(media_type)
    end

    it 'serializes correctly for API calls with URL' do
      text = 'Analyze this'
      image_url = 'https://example.com/test.jpg'
      media_type = 'image/jpeg'

      message = Ai.user_message_with_image_url(text, image_url, media_type)
      json = message.as_json

      expect(json[:role]).to eq('user')
      expect(json[:content]).to be_an(Array)
      expect(json[:content].length).to eq(2)

      # Check text part
      expect(json[:content][0][:type]).to eq('text')
      expect(json[:content][0][:text]).to eq(text)

      # Check image part - should be URL, not base64
      expect(json[:content][1][:type]).to eq('image')
      expect(json[:content][1][:image]).to eq(image_url)
      expect(json[:content][1][:image]).not_to include('base64')
      expect(json[:content][1][:mediaType]).to eq(media_type)
    end

    it 'handles different image URL formats' do
      urls = [
        ['https://example.com/image.png', 'image/png'],
        ['http://test.org/photo.jpg', 'image/jpeg'],
        ['https://cdn.example.com/images/12345.webp', 'image/webp']
      ]

      urls.each do |url, media_type|
        message = Ai.user_message_with_image_url('Test', url, media_type)
        json = message.as_json

        expect(json[:content][1][:image]).to eq(url)
        expect(json[:content][1][:mediaType]).to eq(media_type)
      end
    end

    it 'works with HTTPS URLs' do
      message = Ai.user_message_with_image_url(
        'Analyze',
        'https://secure.example.com/image.jpg',
        'image/jpeg'
      )
      json = message.as_json

      expect(json[:content][1][:image]).to start_with('https://')
    end
  end
end
