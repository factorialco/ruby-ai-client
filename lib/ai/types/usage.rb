# typed: strict

module Ai
  class Usage < T::Struct
    const :input_tokens, Integer, default: 0
    const :output_tokens, Integer, default: 0
    const :total_tokens, Integer, default: 0
    const :reasoning_tokens, T.nilable(Integer), default: nil
    const :cached_input_tokens, T.nilable(Integer), default: nil
  end
end
