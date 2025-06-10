# typed: strict

module Ai
  class Client
    extend T::Sig
    extend T::Helpers

    abstract!

    sig { abstract.returns(T::Array[String]) }
    def agent_names
    end

    sig do
      abstract
        .params(
          agent_name: String,
          messages: T::Array[Ai::Message],
          options: T::Hash[Symbol, T.anything]
        )
        .returns(T::Hash[String, T.anything])
    end
    def generate(agent_name, messages:, options: {})
    end
  end
end
