# typed: strict

module Ai
  class Client
    extend T::Sig
    extend T::Helpers

    abstract!

    # Type aliases for cleaner signatures
    JsonValue =
      T.type_alias do
        T.any(
          String,
          Integer,
          Float,
          T::Boolean,
          NilClass,
          T::Hash[String, T.anything],
          T::Array[T.anything]
        )
      end
    ApiResponse = T.type_alias { T::Hash[String, JsonValue] }
    SchemaHash = T.type_alias { T::Hash[String, T.anything] }

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

    sig { abstract.params(workflow_name: String, input: T::Struct).returns(ApiResponse) }
    def run_workflow(workflow_name, input:)
    end

    sig { abstract.params(workflow_name: String).returns(SchemaHash) }
    def workflow(workflow_name)
    end
  end
end
