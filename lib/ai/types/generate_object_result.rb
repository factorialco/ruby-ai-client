# typed: strict

module Ai
  class GenerateObjectResult < T::Struct
    extend T::Generic

    Elem = type_member

    # The object that was generated
    const :object, Elem
    # Why the language-model call finished (e.g. :stop, :length…)
    const :finish_reason, Ai::FinishReason
    # Usage format
    const :total_usage, T.nilable(TotalUsage), default: nil
    # Provider warnings (e.g. unsupported settings)
    const :warnings, T.nilable(T::Array[CallWarning])
    # Raw request metadata (body, headers, etc.)
    const :request, LanguageModelRequestMetadata
    # Raw response metadata (status, headers, body, messages, …)
    const :response, ResponseMetadata
    # Log-probs if the provider returned them
    const :logprobs, T.nilable(LogProbs)
    # Structured, provider-specific extras
    const :provider_metadata, T.nilable(ProviderMetadata)
    # Back-compat alias (deprecated)
    const :experimental_provider_metadata, T.nilable(ProviderMetadata)
  end
end
