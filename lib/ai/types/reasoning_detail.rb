# typed: strict

module Ai
  class ReasoningDetail < T::Struct
    const :type, String # 'text' | 'redacted'
    const :text, T.nilable(String)
    const :signature, T.nilable(String)
    const :data, T.nilable(String)
  end
end
