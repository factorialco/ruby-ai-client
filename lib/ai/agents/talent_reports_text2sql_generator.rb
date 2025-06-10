# typed: strict

module Ai
  module Agents
    class TalentReportsText2sqlGenerator
      extend T::Sig

      sig { returns(String) }
      def self.agent_name
        "talentReportsText2sqlGenerator"
      end

      sig do
        type_parameters(:O)
          .params(output_class: T.all(T::Class[T.type_parameter(:O)], T::Class[T::Struct]))
          .returns(Ai::Agent::Instance[T.all(T.type_parameter(:O), T::Struct)])
      end
      def self.[](output_class)
        Agent[agent_name, output_class]
      end

      sig do
        params(
          messages: T::Array[Ai::Message],
          runtime_context: T::Hash[String, T.anything],
          max_retries: Integer,
          max_steps: Integer
        ).returns(Ai::GenerateTextResult)
      end
      def self.generate_text(messages:, runtime_context: {}, max_retries: 2, max_steps: 5)
        Agent.generate_text(
          agent_name,
          messages: messages,
          runtime_context: runtime_context,
          max_retries: max_retries,
          max_steps: max_steps
        )
      end
    end
  end
end
