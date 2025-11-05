# typed: strict

RSpec.describe Ai::TextPart do
  describe 'initialization' do
    it 'creates a text part with given text' do
      text_part = Ai::TextPart.new(text: 'Hello, world!')

      expect(text_part.text).to eq('Hello, world!')
      expect(text_part.type).to eq('text')
    end

    it 'handles empty text' do
      text_part = Ai::TextPart.new(text: '')

      expect(text_part.text).to eq('')
      expect(text_part.type).to eq('text')
    end
  end

  describe '#as_json' do
    it 'serializes to the correct format' do
      text_part = Ai::TextPart.new(text: 'Test message')
      json = text_part.as_json

      expect(json).to eq({ type: 'text', text: 'Test message' })
    end

    it 'preserves special characters' do
      text_part = Ai::TextPart.new(text: "Line 1\nLine 2\tTab")
      json = text_part.as_json

      expect(json[:text]).to eq("Line 1\nLine 2\tTab")
    end
  end
end
