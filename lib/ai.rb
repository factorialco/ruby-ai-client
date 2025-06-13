# typed: strict
# frozen_string_literal: true

require_relative 'ai/version'
require 'active_support/all'
require 'action_dispatch'
require 'sorbet-coerce'

module Ai
  extend T::Sig
  include ActiveSupport::Configurable
  extend ActiveSupport::Autoload

  class Error < StandardError
  end

  autoload :Agent, 'ai/agent'
  autoload :Agents, 'ai/agents'
  autoload :Client, 'ai/client'
  autoload :Clients, 'ai/clients'
  autoload :StructToJsonSchema, 'ai/struct_to_json_schema'
  autoload :GenerateObjectResult, 'ai/types/generate_object_result'
  autoload :GenerateTextResult, 'ai/types/generate_text_result'
  autoload :GeneratedFile, 'ai/types/generated_file'
  autoload :LanguageModelRequestMetadata, 'ai/types/language_model_request_metadata'
  autoload :LanguageModelResponseMetadata, 'ai/types/language_model_response_metadata'
  autoload :LanguageModelUsage, 'ai/types/language_model_usage'
  autoload :MessageRole, 'ai/types/message_role'
  autoload :Message, 'ai/types/message'
  autoload :ReasoningDetail, 'ai/types/reasoning_detail'
  autoload :ResponseMessage, 'ai/types/response_message'
  autoload :ResponseMetadata, 'ai/types/response_metadata'
  autoload :StepResult, 'ai/types/step_result'

  ToolSet = T.type_alias { T::Hash[String, T.anything] }
  ToolCall = T.type_alias { T.anything }
  ToolResult = T.type_alias { T.anything }
  ToolCallArray = T.type_alias { T::Array[ToolCall] }
  ToolResultArray = T.type_alias { T::Array[ToolResult] }
  Source = T.type_alias { T.anything }
  FinishReason = T.type_alias { Symbol } # e.g. :stop, :length, …
  CallWarning = T.type_alias { T.anything }
  LogProbs = T.type_alias { T.anything }
  ProviderMetadata = T.type_alias { T.anything }

  config_accessor :origin, :client

  sig { params(content: String).returns(Ai::Message) }
  def self.user_message(content)
    Ai::Message.new(role: Ai::MessageRole::User, content: content)
  end

  sig { params(content: String).returns(Ai::Message) }
  def self.system_message(content)
    Ai::Message.new(role: Ai::MessageRole::System, content: content)
  end

  sig { returns(T.nilable(Ai::Client)) }
  def self.client
    @client ||=
      T.let(
        begin
          if ENV['MASTRA_LOCATION'].present?
            Ai::Clients::Mastra.new(ENV.fetch('MASTRA_LOCATION'))
          else
            config.client
          end
        end,
        T.nilable(Ai::Client)
      )
  end
end
