# typed: strict

module Ai
  class Agent
    extend T::Sig

    sig { returns(String) }
    attr_reader :agent_name

    sig { returns(Ai::Client) }
    attr_reader :client

    sig { params(agent_name: String, client: Ai::Client).void }
    def initialize(agent_name:, client: Ai.client)
      @agent_name = agent_name
      @client = client
    end

    sig do
      params(
        messages: T::Array[Ai::Message],
        runtime_context: T::Hash[String, T.anything],
        max_retries: Integer,
        max_steps: Integer,
        telemetry: Ai::TelemetrySettings
      ).returns(Ai::GenerateTextResult)
    end
    def generate_text(messages:, runtime_context: {}, max_retries: 2, max_steps: 5, telemetry: Ai::TelemetrySettings.new)
      options = { runtime_context: runtime_context, max_retries: max_retries, max_steps: max_steps, telemetry: telemetry }

      data = client.generate(agent_name, messages: messages, options: options)
      TypeCoerce[Ai::GenerateTextResult].new.from(data, raise_coercion_error: false)
    end

    sig do
      type_parameters(:O)
        .params(
          messages: T::Array[Ai::Message],
          output_class: T.all(T::Class[T.type_parameter(:O)], T::Class[T::Struct]),
          runtime_context: T::Hash[String, T.anything],
          max_retries: Integer,
          max_steps: Integer,
          telemetry: Ai::TelemetrySettings
        )
        .returns(GenerateObjectResult[T.type_parameter(:O)])
    end
    def generate_object(messages:, output_class:, runtime_context: {}, max_retries: 2, max_steps: 5, telemetry: Ai::TelemetrySettings.new)
      output = Ai::StructToJsonSchema.convert(T.cast(output_class, T.class_of(T::Struct)))

      options = {
        runtime_context: runtime_context,
        max_retries: max_retries,
        max_steps: max_steps,
        output: output,
        telemetry: telemetry
      }

      data = client.generate(agent_name, messages: messages, options: options)

      object = TypeCoerce[output_class].from(data['object'])
      TypeCoerce[GenerateObjectResult]
        .new
        .from(data, raise_coercion_error: false)
        .with(object: object)
    end
  end
end
