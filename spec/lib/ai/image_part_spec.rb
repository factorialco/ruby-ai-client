# typed: strict

RSpec.describe Ai::ImagePart do
  describe 'initialization' do
    it 'creates an image part with given data and media type' do
      image_data = 'binary image data'
      image_part = Ai::ImagePart.new(image_data: image_data, media_type: 'image/png')

      expect(image_part.image_data).to eq(image_data)
      expect(image_part.media_type).to eq('image/png')
      expect(image_part.type).to eq('image')
    end

    it 'creates an image part with URL and media type' do
      image_url = 'https://example.com/image.jpg'
      image_part = Ai::ImagePart.new(image_url: image_url, media_type: 'image/jpeg')

      expect(image_part.image_url).to eq(image_url)
      expect(image_part.image_data).to be_nil
      expect(image_part.media_type).to eq('image/jpeg')
      expect(image_part.type).to eq('image')
    end

    it 'accepts different media types' do
      image_part = Ai::ImagePart.new(image_data: 'data', media_type: 'image/jpeg')

      expect(image_part.media_type).to eq('image/jpeg')
    end

    it 'raises error when neither image_data nor image_url is provided' do
      expect do
        Ai::ImagePart.new(media_type: 'image/png')
      end.to raise_error(ArgumentError, "Either image_data or image_url must be provided")
    end

    it 'raises error when both image_data and image_url are provided' do
      expect do
        Ai::ImagePart.new(
          image_data: 'data',
          image_url: 'https://example.com/image.jpg',
          media_type: 'image/png'
        )
      end.to raise_error(ArgumentError, "Cannot provide both image_data and image_url")
    end
  end

  describe '#as_json' do
    it 'serializes to the correct format with base64 encoding' do
      image_data = 'test data'
      image_part = Ai::ImagePart.new(image_data: image_data, media_type: 'image/png')
      json = image_part.as_json

      expected_base64 = Base64.strict_encode64(image_data)
      expect(json[:type]).to eq('image')
      expect(json[:image]).to eq("data:image/png;base64,#{expected_base64}")
      expect(json[:mediaType]).to eq('image/png')
    end

    it 'properly encodes binary data' do
      # Create some binary data (simulating image bytes)
      binary_data = [137, 80, 78, 71, 13, 10, 26, 10].pack('C*') # PNG header
      image_part = Ai::ImagePart.new(image_data: binary_data, media_type: 'image/png')
      json = image_part.as_json

      # Verify it's a valid data URI
      expect(json[:image]).to match(%r{^data:image/png;base64,})

      # Verify we can decode it back
      base64_part = json[:image].gsub('data:image/png;base64,', '')
      decoded = Base64.strict_decode64(base64_part)
      expect(decoded).to eq(binary_data)
    end

    it 'handles different image formats' do
      formats = [
        ['image/jpeg', 'JPEG data'],
        ['image/gif', 'GIF data'],
        ['image/webp', 'WEBP data']
      ]

      formats.each do |media_type, data|
        image_part = Ai::ImagePart.new(image_data: data, media_type: media_type)
        json = image_part.as_json

        expect(json[:image]).to start_with("data:#{media_type};base64,")
        expect(json[:mediaType]).to eq(media_type)
      end
    end

    it 'serializes URL-based images correctly' do
      image_url = 'https://example.com/photo.jpg'
      image_part = Ai::ImagePart.new(image_url: image_url, media_type: 'image/jpeg')
      json = image_part.as_json

      expect(json[:type]).to eq('image')
      expect(json[:image]).to eq(image_url)
      expect(json[:mediaType]).to eq('image/jpeg')
    end

    it 'handles different URL formats' do
      urls = [
        'https://example.com/image.png',
        'http://test.org/photo.jpg',
        'https://cdn.example.com/images/12345.webp'
      ]

      urls.each do |url|
        image_part = Ai::ImagePart.new(image_url: url, media_type: 'image/jpeg')
        json = image_part.as_json

        expect(json[:image]).to eq(url)
        expect(json[:image]).not_to include('base64')
      end
    end
  end
end
