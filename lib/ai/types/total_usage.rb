# typed: strict

module Ai
  class TotalUsage < T::Struct
    const :input_tokens, Integer
    const :output_tokens, Integer
    const :total_tokens, Integer
    const :reasoning_tokens, T.nilable(Integer), default: nil
    const :cached_input_tokens, T.nilable(Integer), default: nil
  end
end
