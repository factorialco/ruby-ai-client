# typed: strict

module Ai
  class ResponseMessage < T::Struct
    const :id, String
    const :content, T.anything # assistant / tool message content
  end
end
