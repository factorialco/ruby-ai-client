# typed: strict

module Ai
  class GenerateTextResult < T::Struct
    extend T::Sig

    const :text, String
    const :reasoning, T.nilable(String)
    const :files, T::Array[GeneratedFile]
    const :reasoning_details, T::Array[ReasoningDetail]
    const :sources, T::Array[Source]
    const :experimental_output, T.anything
    const :tool_calls, ToolCallArray
    const :tool_results, ToolResultArray
    const :finish_reason, FinishReason
    const :usage, LanguageModelUsage
    const :warnings, T.nilable(T::Array[CallWarning])
    const :steps, T::Array[StepResult]
    const :request, LanguageModelRequestMetadata
    const :response, ResponseMetadata
    const :logprobs, T.nilable(LogProbs)
    const :provider_metadata, T.nilable(ProviderMetadata)
    const :experimental_provider_metadata, T.nilable(ProviderMetadata)
  end
end
