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
        telemetry: Ai::TelemetrySettings,
        delegated_auth: T.nilable(T.anything)
      ).returns(Ai::GenerateTextResult)
    end
    def generate_text(
      messages:,
      runtime_context: {},
      max_retries: 2,
      max_steps: 5,
      telemetry: Ai::TelemetrySettings.new,
      delegated_auth: nil
    )
      options = {
        runtime_context: runtime_context,
        max_retries: max_retries,
        max_steps: max_steps,
        telemetry: telemetry
      }

      delegated_token = resolve_delegated_token(delegated_auth)
      data = client.generate(agent_name, messages: messages, options: options, delegated_token: delegated_token)
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
          telemetry: Ai::TelemetrySettings,
          delegated_auth: T.nilable(T.anything)
        )
        .returns(GenerateObjectResult[T.type_parameter(:O)])
    end
    def generate_object(
      messages:,
      output_class:,
      runtime_context: {},
      max_retries: 2,
      max_steps: 5,
      telemetry: Ai::TelemetrySettings.new,
      delegated_auth: nil
    )
      schema = Ai::StructToJsonSchema.convert(T.cast(output_class, T.class_of(T::Struct)))

      options = {
        runtime_context: runtime_context,
        max_retries: max_retries,
        max_steps: max_steps,
        structured_output: {
          schema: schema
        },
        telemetry: telemetry
      }

      delegated_token = resolve_delegated_token(delegated_auth)
      data = client.generate(agent_name, messages: messages, options: options, delegated_token: delegated_token)

      object = TypeCoerce[output_class].from(data['object'])
      TypeCoerce[GenerateObjectResult]
        .new
        .from(data, raise_coercion_error: false)
        .with(object: object)
    end

    private

    sig { params(delegated_auth: T.nilable(T.anything)).returns(T.nilable(String)) }
    def resolve_delegated_token(delegated_auth)
      return nil if delegated_auth.nil?

      resolver = Ai.config.delegated_token_resolver
      raise Ai::Error, 'delegated_token_resolver is not configured. Set Ai.delegated_token_resolver in your initializer.' if resolver.nil?

      resolver.call(delegated_auth)
    end
  end
end
