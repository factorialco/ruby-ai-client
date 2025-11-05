# typed: strict

RSpec.describe Ai::Message do
  describe 'with string content' do
    it 'creates a message with string content' do
      message = Ai::Message.new(role: Ai::MessageRole::User, content: 'Hello')

      expect(message.role).to eq(Ai::MessageRole::User)
      expect(message.content).to eq('Hello')
    end

    it 'serializes string content correctly' do
      message = Ai::Message.new(role: Ai::MessageRole::User, content: 'Test message')
      json = message.as_json

      expect(json[:role]).to eq('user')
      expect(json[:content]).to eq('Test message')
    end
  end

  describe 'with multipart content' do
    it 'creates a message with text and image parts' do
      text_part = Ai::TextPart.new(text: 'What is this?')
      image_part = Ai::ImagePart.new(image_data: 'binary data', media_type: 'image/png')
      message = Ai::Message.new(role: Ai::MessageRole::User, content: [text_part, image_part])

      expect(message.role).to eq(Ai::MessageRole::User)
      expect(message.content).to be_an(Array)
      expect(message.content.length).to eq(2)
    end

    it 'serializes multipart content correctly' do
      text_part = Ai::TextPart.new(text: 'Describe this image')
      image_data = 'test image data'
      image_part = Ai::ImagePart.new(image_data: image_data, media_type: 'image/jpeg')
      message = Ai::Message.new(role: Ai::MessageRole::User, content: [text_part, image_part])

      json = message.as_json

      expect(json[:role]).to eq('user')
      expect(json[:content]).to be_an(Array)
      expect(json[:content].length).to eq(2)

      # Check text part
      expect(json[:content][0][:type]).to eq('text')
      expect(json[:content][0][:text]).to eq('Describe this image')

      # Check image part
      expect(json[:content][1][:type]).to eq('image')
      expect(json[:content][1][:image]).to start_with('data:image/jpeg;base64,')
      expect(json[:content][1][:mediaType]).to eq('image/jpeg')
    end

    it 'handles multiple images in one message' do
      text_part = Ai::TextPart.new(text: 'Compare these images')
      image1 = Ai::ImagePart.new(image_data: 'image1 data', media_type: 'image/png')
      image2 = Ai::ImagePart.new(image_data: 'image2 data', media_type: 'image/jpeg')

      message = Ai::Message.new(role: Ai::MessageRole::User, content: [text_part, image1, image2])
      json = message.as_json

      expect(json[:content].length).to eq(3)
      expect(json[:content][0][:type]).to eq('text')
      expect(json[:content][1][:type]).to eq('image')
      expect(json[:content][2][:type]).to eq('image')
    end

    it 'handles text-only multipart content' do
      text1 = Ai::TextPart.new(text: 'First part')
      text2 = Ai::TextPart.new(text: 'Second part')
      message = Ai::Message.new(role: Ai::MessageRole::User, content: [text1, text2])

      json = message.as_json

      expect(json[:content]).to be_an(Array)
      expect(json[:content].length).to eq(2)
      expect(json[:content][0]).to eq({ type: 'text', text: 'First part' })
      expect(json[:content][1]).to eq({ type: 'text', text: 'Second part' })
    end
  end

  describe 'role serialization' do
    it 'serializes different roles correctly' do
      roles = [
        [Ai::MessageRole::User, 'user'],
        [Ai::MessageRole::Assistant, 'assistant'],
        [Ai::MessageRole::System, 'system']
      ]

      roles.each do |role, expected_string|
        message = Ai::Message.new(role: role, content: 'test')
        json = message.as_json

        expect(json[:role]).to eq(expected_string)
      end
    end
  end
end
