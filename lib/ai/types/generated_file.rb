# typed: strict

module Ai
  class GeneratedFile < T::Struct
    const :base64, String
    const :uint8_array, T::Array[Integer] # byte values
    const :mime_type, String
  end
end
