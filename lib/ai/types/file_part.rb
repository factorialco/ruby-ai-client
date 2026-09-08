# typed: strict

require 'base64'

module Ai
  class FilePart < T::Struct
    extend T::Sig

    const :type, String, default: 'file'
    const :file_data, String
    const :media_type, String
    const :filename, T.nilable(String), default: nil

    sig { returns(T::Hash[Symbol, String]) }
    def as_json
      encoded = Base64.strict_encode64(file_data.b)
      json = { type: type, data: "data:#{media_type};base64,#{encoded}", mediaType: media_type }
      json[:filename] = T.must(filename) if filename
      json
    end
  end
end
