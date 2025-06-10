# typed: strict

module Ai
  class LanguageModelUsage < T::Struct
    const :prompt_tokens, Integer
    const :completion_tokens, Integer
    const :total_tokens, Integer
  end
end
