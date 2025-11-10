# typed: strict

module Ai
  MessageContent = T.type_alias { T.any(String, T::Array[T.any(Ai::TextPart, Ai::ImagePart)]) }

  class Message < T::Struct
    extend T::Sig

    const :role, Ai::MessageRole
    const :content, MessageContent

    sig do
      returns(
        T::Hash[
          Symbol,
          T.any(String, T::Array[T::Hash[Symbol, String]])
        ]
      )
    end
    def as_json
      serialized_content =
        if content.is_a?(String)
          content
        else
          T.cast(content, T::Array[T.any(Ai::TextPart, Ai::ImagePart)]).map(&:as_json)
        end

      { role: role.serialize, content: serialized_content }
    end
  end
end
