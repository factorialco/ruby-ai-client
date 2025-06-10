# typed: strict

module Ai
  class MessageRole < T::Enum
    enums do
      User = new("user")
      Assistant = new("assistant")
      System = new("system")
      Data = new("data")
    end
  end
end
