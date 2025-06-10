# typed: strict

module Ai
  class Message < T::Struct
    const :role, Ai::MessageRole
    const :content, String
  end
end
