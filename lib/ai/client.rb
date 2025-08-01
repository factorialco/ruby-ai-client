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

    sig do
      abstract
        .params(workflow_name: String, input: T::Struct)
        .returns(T::Hash[T.untyped, T.untyped])
    end
    def run_workflow(workflow_name, input:)
    end

    sig { abstract.params(workflow_name: String).returns(T::Hash[String, T.untyped]) }
    def get_workflow(workflow_name)
    end
  end
end
