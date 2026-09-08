# typed: strict

RSpec.describe Ai::FilePart do
  describe 'initialization' do
    it 'creates a file part with given data and media type' do
      file_part = Ai::FilePart.new(file_data: 'binary pdf data', media_type: 'application/pdf')

      expect(file_part.file_data).to eq('binary pdf data')
      expect(file_part.media_type).to eq('application/pdf')
      expect(file_part.filename).to be_nil
      expect(file_part.type).to eq('file')
    end

    it 'accepts an optional filename' do
      file_part =
        Ai::FilePart.new(
          file_data: 'data',
          media_type: 'application/pdf',
          filename: 'invoice.pdf'
        )

      expect(file_part.filename).to eq('invoice.pdf')
    end
  end

  describe '#as_json' do
    it 'serializes to a data URL with base64 encoding' do
      file_part = Ai::FilePart.new(file_data: 'test data', media_type: 'application/pdf')

      json = file_part.as_json

      expect(json[:type]).to eq('file')
      expect(json[:mediaType]).to eq('application/pdf')
      expect(json[:data]).to eq("data:application/pdf;base64,#{Base64.strict_encode64('test data')}")
      expect(json).not_to have_key(:filename)
    end

    it 'includes the filename when present' do
      file_part =
        Ai::FilePart.new(
          file_data: 'test data',
          media_type: 'application/pdf',
          filename: 'invoice.pdf'
        )

      expect(file_part.as_json[:filename]).to eq('invoice.pdf')
    end

    it 'handles binary data safely' do
      binary = (0..255).map(&:chr).join
      file_part = Ai::FilePart.new(file_data: binary, media_type: 'application/pdf')

      expect(file_part.as_json[:data]).to eq(
        "data:application/pdf;base64,#{Base64.strict_encode64(binary.b)}"
      )
    end
  end
end
