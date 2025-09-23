# typed: strict

module Ai
  class LanguageModelUsage < T::Struct
    # Legacy fields
    const :prompt_tokens, Integer
    const :completion_tokens, Integer
    const :total_tokens, Integer

    # VNext fields
    const :input_tokens, T.nilable(Integer), default: nil
    const :output_tokens, T.nilable(Integer), default: nil
    const :reasoning_tokens, T.nilable(Integer), default: nil
    const :cached_input_tokens, T.nilable(Integer), default: nil
  end
end
