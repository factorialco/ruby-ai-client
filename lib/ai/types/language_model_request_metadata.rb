# typed: strict

module Ai
  class LanguageModelRequestMetadata < T::Struct
    const :body, T.nilable(String) # raw JSON string sent to provider
  end
end
