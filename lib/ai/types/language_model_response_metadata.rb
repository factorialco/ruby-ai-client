# typed: strict

module Ai
  class LanguageModelResponseMetadata < T::Struct
    const :id, String
    const :timestamp, Time
    const :model_id, String
    const :headers, T.nilable(T::Hash[String, String])
  end
end
