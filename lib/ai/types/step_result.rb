# typed: strict

module Ai
  class StepResult < T::Struct
    const :text, String
    const :reasoning, T.nilable(String)
    const :reasoning_details, T::Array[ReasoningDetail]
    const :files, T::Array[GeneratedFile]
    const :sources, T::Array[Source]
    const :tool_calls, ToolCallArray
    const :tool_results, ToolResultArray
    const :finish_reason, FinishReason
    const :total_usage, T.nilable(TotalUsage), default: nil
    const :warnings, T.nilable(T::Array[CallWarning])
    const :logprobs, T.nilable(LogProbs)
    const :request, LanguageModelRequestMetadata
    const :response, ResponseMetadata
    const :provider_metadata, T.nilable(ProviderMetadata)
    const :experimental_provider_metadata, T.nilable(ProviderMetadata)
    const :step_type, String # 'initial' | 'continue' | 'tool-result'
    const :is_continued, T::Boolean
  end
end
