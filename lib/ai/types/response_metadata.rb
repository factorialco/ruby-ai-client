# typed: strict

module Ai
  # Intersection of LanguageModelResponseMetadata with extra fields
  class ResponseMetadata < T::Struct
    const :id, String
    const :timestamp, Time
    const :model_id, String
    const :headers, T.nilable(T::Hash[String, String])
    const :body, T.anything
  end
end
