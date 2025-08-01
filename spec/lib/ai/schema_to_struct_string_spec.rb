# typed: strict
# frozen_string_literal: true

require 'ai/schema_to_struct_string'

RSpec.describe Ai::SchemaToStructString do
  subject(:converter) { described_class }

  let(:endpoint) { 'https://mastra.local.factorial.dev' }
  let(:client) { Ai::Clients::Mastra.new(endpoint) }
  let(:workflow_name) { 'testWorkflow' }

  # getting real zod schema converted to json schema
  # inputSchema: z.object({
  #   first_number: z.number(),
  #   second_number: z.number(),
  #   testing_params: z.object({
  #     string_param: z.string().min(1).max(50).optional(),
  #     number_param: z.number().int().positive().lt(1000),
  #     boolean_param: z.boolean(),
  #     array_param: z.array(z.string()).nonempty(),
  #     enum_param: z.enum(['option1', 'option2', 'option3']),
  #     date_param: z.coerce.date(),
  #     tuple_param: z.tuple([z.string(), z.number(), z.boolean()]),
  #     union_param: z.union([z.string(), z.number()]),
  #     nested_param: z.object({
  #       id: z.string().uuid(),
  #       tags: z.array(z.string()).max(5),
  #     }),
  #     literal_param: z.literal('fixed_value'),
  #     defaulted_param: z.string().default('hello'),
  #     any_param: z.any().optional(),
  #   }).optional(),
  # })
  let(:schema_string) do
    VCR.use_cassette('mastra_get_workflow') do
      workflow = client.workflow(workflow_name)
      workflow.fetch('input_schema')
    end
  end

  describe '.convert' do
    it 'generates T::Struct definitions for nested objects' do
      expected = <<~RUBY.strip
        class NestedParam < T::Struct
          # format: uuid
          const :id, String
          # maxItems: 5
          const :tags, T::Array[String]
        end

        class EnumParamEnum < T::Enum
          enums do
            Option1 = new('option1')
            Option2 = new('option2')
            Option3 = new('option3')
          end
        end

        class TestingParams < T::Struct
          # minLength: 1, maxLength: 50
          const :string_param, T.nilable(String)
          # exclusiveMinimum: 0, exclusiveMaximum: 1000
          const :number_param, Integer
          const :boolean_param, T::Boolean
          # minItems: 1
          const :array_param, T::Array[String]
          const :enum_param, EnumParamEnum
          # format: date-time
          const :date_param, Time
          # minItems: 3, maxItems: 3
          const :tuple_param, T::Array[T.any(String, Float, T::Boolean)]
          const :union_param, T.any(String, Float)
          const :nested_param, NestedParam
          # const: "fixed_value"
          const :literal_param, String
          # default: "hello"
          const :defaulted_param, T.nilable(String)
          const :any_param, T.untyped
        end

        class Input < T::Struct
          const :first_number, Float
          const :second_number, Float
          const :testing_params, T.nilable(TestingParams)
        end
      RUBY

      result = converter.convert(schema_string, class_name: 'Input')

      expect(result).to eq(expected)
    end
  end
end
