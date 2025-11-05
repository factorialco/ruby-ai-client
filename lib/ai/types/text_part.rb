# typed: strict

module Ai
  class TextPart < T::Struct
    extend T::Sig

    const :type, String, default: 'text'
    const :text, String

    sig { returns(T::Hash[Symbol, String]) }
    def as_json
      { type: type, text: text }
    end
  end
end
