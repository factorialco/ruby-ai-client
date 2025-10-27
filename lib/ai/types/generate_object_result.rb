# typed: strict

module Ai
  class GenerateObjectResult < T::Struct
    extend T::Generic

    Elem = type_member

    const :object, Elem
    const :finish_reason, Ai::FinishReason
    const :usage, T.nilable(Usage), default: nil
    const :total_usage, T.nilable(Usage), default: nil
    const :warnings, T.nilable(T::Array[CallWarning])
    const :request, LanguageModelRequestMetadata
    const :response, ResponseMetadata
    const :logprobs, T.nilable(LogProbs)
    const :provider_metadata, T.nilable(ProviderMetadata)
    const :trace_id, T.nilable(String)
  end
end
