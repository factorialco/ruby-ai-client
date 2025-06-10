# typed: strict

module Ai
  class Client
    extend T::Sig
    extend T::Helpers

    abstract!

    sig do
      abstract
        .params(
          agent_name: String,
          messages: T::Array[Ai::Message],
          runtime_context: T::Hash[String, T.anything],
          max_retries: Integer,
          max_steps: Integer
        )
        .returns(T::Hash[String, T.anything])
    end
    def generate_agent_text(
      agent_name,
      messages:,
      runtime_context: {},
      max_retries: 2,
      max_steps: 5
    )
    end

    sig do
      abstract
        .params(
          agent_name: String,
          messages: T::Array[Ai::Message],
          output: T::Hash[String, T.anything],
          runtime_context: T::Hash[String, T.anything],
          max_retries: Integer,
          max_steps: Integer
        )
        .returns(T::Hash[String, T.anything])
    end
    def generate_agent_object(
      agent_name,
      messages:,
      output:,
      runtime_context: {},
      max_retries: 2,
      max_steps: 5
    )
    end
  end
end
