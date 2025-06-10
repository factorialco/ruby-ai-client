# typed: strict

module Ai
  class Agent
    extend T::Sig

    class Instance
      extend T::Sig
      extend T::Generic

      Output = type_member

      sig { returns(String) }
      attr_reader :agent_name

      sig { returns(T.nilable(T::Class[Output])) }
      attr_reader :output_class

      sig { returns(Ai::Client) }
      attr_reader :client

      sig do
        params(
          agent_name: String,
          client: Ai::Client,
          output_class: T.nilable(T::Class[Output])
        ).void
      end
      def initialize(agent_name:, client:, output_class: nil)
        @agent_name = agent_name
        @client = client
        @output_class = output_class
      end

      sig do
        params(
          messages: T::Array[Ai::Message],
          runtime_context: T::Hash[String, T.anything],
          max_retries: Integer,
          max_steps: Integer
        ).returns(Ai::GenerateTextResult)
      end
      def generate_text(messages:, runtime_context: {}, max_retries: 2, max_steps: 5)
        data =
          client.generate_agent_text(
            agent_name,
            messages: messages,
            runtime_context: runtime_context,
            max_retries: max_retries,
            max_steps: max_steps
          )
        TypeCoerce[Ai::GenerateTextResult].new.from(data, raise_coercion_error: false)
      end

      sig do
        params(
          messages: T::Array[Ai::Message],
          runtime_context: T::Hash[String, T.anything],
          max_retries: Integer,
          max_steps: Integer
        ).returns(GenerateObjectResult[Output])
      end
      def generate_object(messages:, runtime_context: {}, max_retries: 2, max_steps: 5)
        if output_class.nil?
          raise "You need to provide an output class for #{agent_name} when calling generate_object"
        end

        output = Ai::StructToJsonSchema.convert(T.cast(output_class, T.class_of(T::Struct)))

        data =
          client.generate_agent_object(
            agent_name,
            messages: messages,
            runtime_context: runtime_context,
            max_retries: max_retries,
            max_steps: max_steps,
            output: output
          )

        object = TypeCoerce[output_class].from(data['object'])
        TypeCoerce[GenerateObjectResult[Output]]
          .new
          .from(data, raise_coercion_error: false)
          .with(object: object)
      end
    end

    sig do
      type_parameters(:O)
        .params(
          agent_name: String,
          output_class: T.all(T::Class[T.type_parameter(:O)], T::Class[T::Struct]),
          client: Ai::Client
        )
        .returns(Ai::Agent::Instance[T.all(T.type_parameter(:O), T::Struct)])
    end
    def self.[](agent_name, output_class, client: Ai.client)
      Instance.new(agent_name: agent_name, output_class: output_class, client: client)
    end

    sig do
      params(
        agent_name: String,
        messages: T::Array[Ai::Message],
        runtime_context: T::Hash[String, T.anything],
        max_retries: Integer,
        max_steps: Integer,
        client: Ai::Client
      ).returns(Ai::GenerateTextResult)
    end
    def self.generate_text(
      agent_name,
      messages:,
      runtime_context: {},
      max_retries: 2,
      max_steps: 5,
      client: Ai.client
    )
      Instance.new(agent_name: agent_name, client: client).generate_text(
        messages: messages,
        runtime_context: runtime_context,
        max_retries: max_retries,
        max_steps: max_steps
      )
    end
  end
end
