# typed: strict
# frozen_string_literal: true

module Ai
  # Included by every generated `Ai::Workflows::*` class so callers can accept a
  # workflow as a typed argument instead of `T.untyped`.
  #
  #   sig do
  #     params(workflow: T.all(T::Class[Ai::Workflow], Ai::Workflow::ClassMethods)).void
  #   end
  #   def run(workflow:) = workflow.call(input, headers:)
  #
  # `call` returns the workflow's own nested `Output`, which differs per class,
  # so this interface types it as `T::Struct`. A caller that needs the concrete
  # type still narrows it itself.
  module Workflow
    extend T::Sig
    extend T::Helpers

    interface!

    module ClassMethods
      extend T::Sig
      extend T::Helpers

      abstract!

      # `input` is untyped so each class can narrow it to its own `Input`; a
      # concrete type here would make that narrowing an illegal override.
      sig do
        abstract
          .params(input: T.untyped, headers: T::Hash[String, String]) # rubocop:disable Sorbet/ForbidTUntyped
          .returns(T::Struct)
      end
      def call(input, headers: {})
      end
    end

    mixes_in_class_methods(ClassMethods)
  end
end
