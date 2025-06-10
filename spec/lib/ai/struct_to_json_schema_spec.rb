# typed: strict
require 'json_schemer'

RSpec.describe Ai::StructToJsonSchema do
  describe '.convert' do
    context 'with empty struct' do
      let(:empty_struct_class) { Class.new(T::Struct) { extend T::Sig } }
      let(:expected_schema) do
        {
          type: 'object',
          properties: {
          },
          required: [],
          additionalProperties: false
        }.deep_stringify_keys
      end

      it 'generates a valid, empty JSON Schema object' do
        result = described_class.convert(empty_struct_class)

        aggregate_failures do
          expect(result).to eq(expected_schema)
          expect(JSONSchemer).to be_valid_schema(
            result,
            meta_schema: 'http://json-schema.org/draft-06/schema#'
          )
        end
      end
    end

    context 'with primitive types' do
      let(:primitive_struct_class) do
        Class.new(T::Struct) do
          extend T::Sig

          const :string_field, String, extra: { desc: 'A string field' }
          const :integer_field, Integer, extra: { desc: 'An integer field' }
          const :float_field, Float, extra: { desc: 'A floating point number field' }
          const :boolean_field, T::Boolean, extra: { desc: 'A boolean field' }
          const :nullable_string, T.nilable(String), extra: { desc: 'A nullable string field' }
          const :any_field,
                T.nilable(T.any(T::Boolean, String, Integer)),
                extra: {
                  desc: 'A field that can be boolean, string, integer, or null'
                }
        end
      end
      let(:expected_schema) do
        {
          type: 'object',
          properties: {
            string_field: {
              type: 'string',
              description: 'A string field'
            },
            integer_field: {
              type: 'integer',
              description: 'An integer field'
            },
            float_field: {
              type: 'number',
              description: 'A floating point number field'
            },
            boolean_field: {
              type: 'boolean',
              description: 'A boolean field'
            },
            nullable_string: {
              'anyOf' => [{ type: 'string' }, { type: 'null' }],
              :description => 'A nullable string field'
            },
            any_field: {
              'anyOf' => [
                { type: 'boolean' },
                { type: 'string' },
                { type: 'integer' },
                { type: 'null' }
              ],
              :description => 'A field that can be boolean, string, integer, or null'
            }
          },
          required: %w[
            string_field
            integer_field
            float_field
            boolean_field
            nullable_string
            any_field
          ],
          additionalProperties: false
        }.deep_stringify_keys
      end

      it 'generates a valid JSON Schema with primitive types, descriptions and marks all fields as required' do
        result = described_class.convert(primitive_struct_class)

        aggregate_failures do
          expect(result).to eq(expected_schema)
          expect(JSONSchemer).to be_valid_schema(
            result,
            meta_schema: 'http://json-schema.org/draft-06/schema#'
          )
        end
      end
    end

    context 'with skipped fields' do
      let(:skipped_fields_struct_class) do
        Class.new(T::Struct) do
          extend T::Sig

          const :included_string, String, extra: { desc: 'A string field that should be included' }
          const :skipped_string, String, extra: { skip: true }
          const :included_integer,
                Integer,
                extra: {
                  desc: 'An integer field that should be included'
                }
          const :skipped_integer, Integer, extra: { skip: true }
        end
      end
      let(:expected_schema) do
        {
          type: 'object',
          properties: {
            included_string: {
              type: 'string',
              description: 'A string field that should be included'
            },
            included_integer: {
              type: 'integer',
              description: 'An integer field that should be included'
            }
          },
          required: %w[included_string included_integer],
          additionalProperties: false
        }.deep_stringify_keys
      end

      it 'generates a valid JSON Schema that excludes fields marked with skip: true' do
        result = described_class.convert(skipped_fields_struct_class)

        aggregate_failures do
          expect(result).to eq(expected_schema)
          expect(JSONSchemer).to be_valid_schema(
            result,
            meta_schema: 'http://json-schema.org/draft-06/schema#'
          )
          expect(result['properties'].keys).not_to include('skipped_string')
          expect(result['required']).not_to include('skipped_string')
        end
      end
    end

    context 'with nested structs' do
      let(:inner_struct_class) do
        Class.new(T::Struct) do
          extend T::Sig

          const :inner_string, String, extra: { desc: 'String field inside InnerStruct' }
          const :inner_integer, Integer, extra: { desc: 'Integer field inside InnerStruct' }
        end
      end

      let(:nested_struct_class) do
        inner_struct_def = inner_struct_class
        Class.new(T::Struct) do
          extend T::Sig

          const :outer_string, String, extra: { desc: 'String field at top level' }
          const :inner, inner_struct_def, extra: { desc: 'Nested InnerStruct' }
        end
      end

      let(:expected_schema) do
        {
          type: 'object',
          properties: {
            outer_string: {
              type: 'string',
              description: 'String field at top level'
            },
            inner: {
              type: 'object',
              properties: {
                inner_string: {
                  type: 'string',
                  description: 'String field inside InnerStruct'
                },
                inner_integer: {
                  type: 'integer',
                  description: 'Integer field inside InnerStruct'
                }
              },
              required: %w[inner_string inner_integer],
              additionalProperties: false,
              description: 'Nested InnerStruct'
            }
          },
          required: %w[outer_string inner],
          additionalProperties: false
        }.deep_stringify_keys
      end

      it 'generates a valid JSON Schema with nested structs' do
        result = described_class.convert(nested_struct_class)

        aggregate_failures do
          expect(result).to eq(expected_schema)
          expect(JSONSchemer).to be_valid_schema(
            result,
            meta_schema: 'http://json-schema.org/draft-06/schema#'
          )
        end
      end
    end

    context 'with deep nesting' do
      let(:inner_struct_class) do
        Class.new(T::Struct) do
          extend T::Sig

          const :inner_string, String, extra: { desc: 'String field inside InnerStruct' }
          const :inner_integer, Integer, extra: { desc: 'Integer field inside InnerStruct' }
        end
      end

      let(:deep_nested_struct_class) do
        inner_struct_def = inner_struct_class
        innermost_struct =
          Class.new(T::Struct) do
            extend T::Sig

            const :innermost_string, String, extra: { desc: 'String field at the innermost level' }
          end

        middle_struct =
          Class.new(T::Struct) do
            extend T::Sig

            const :middle_string, String, extra: { desc: 'String field at the middle level' }
            const :innermost, innermost_struct, extra: { desc: 'Innermost struct' }
            const :inner, inner_struct_def, extra: { desc: 'Inner struct (named)' }
          end

        Class.new(T::Struct) do
          extend T::Sig

          const :outer_string, String, extra: { desc: 'String field at the outer level' }
          const :middle, middle_struct, extra: { desc: 'Middle level struct' }
        end
      end

      let(:expected_schema) do
        {
          type: 'object',
          properties: {
            outer_string: {
              type: 'string',
              description: 'String field at the outer level'
            },
            middle: {
              type: 'object',
              properties: {
                middle_string: {
                  type: 'string',
                  description: 'String field at the middle level'
                },
                innermost: {
                  type: 'object',
                  properties: {
                    innermost_string: {
                      type: 'string',
                      description: 'String field at the innermost level'
                    }
                  },
                  required: ['innermost_string'],
                  additionalProperties: false,
                  description: 'Innermost struct'
                },
                inner: {
                  type: 'object',
                  properties: {
                    inner_string: {
                      type: 'string',
                      description: 'String field inside InnerStruct'
                    },
                    inner_integer: {
                      type: 'integer',
                      description: 'Integer field inside InnerStruct'
                    }
                  },
                  required: %w[inner_string inner_integer],
                  additionalProperties: false,
                  description: 'Inner struct (named)'
                }
              },
              required: %w[middle_string innermost inner],
              additionalProperties: false,
              description: 'Middle level struct'
            }
          },
          required: %w[outer_string middle],
          additionalProperties: false
        }.deep_stringify_keys
      end

      it 'generates a valid JSON Schema with deep nesting' do
        result = described_class.convert(deep_nested_struct_class)

        aggregate_failures do
          expect(result).to eq(expected_schema)
          expect(JSONSchemer).to be_valid_schema(
            result,
            meta_schema: 'http://json-schema.org/draft-06/schema#'
          )
        end
      end
    end

    context 'with enum types' do
      class TestEnum < T::Enum
        extend T::Sig

        enums do
          VALUE1 = new('value1')
          VALUE2 = new('value2')
          VALUE3 = new('value3')
        end
      end

      let(:enum_struct_class) do
        Class.new(T::Struct) do
          extend T::Sig

          const :enum_field, TestEnum, extra: { desc: 'An enum field' }
          const :nullable_enum, T.nilable(TestEnum), extra: { desc: 'A nullable enum field' }
        end
      end

      let(:expected_schema) do
        {
          type: 'object',
          properties: {
            enum_field: {
              type: 'string',
              enum: %w[value1 value2 value3],
              description: 'An enum field'
            },
            nullable_enum: {
              'anyOf' => [{ type: 'string', enum: %w[value1 value2 value3] }, { type: 'null' }],
              :description => 'A nullable enum field'
            }
          },
          required: %w[enum_field nullable_enum],
          additionalProperties: false
        }.deep_stringify_keys
      end

      it 'generates a valid JSON Schema with enum types' do
        result = described_class.convert(enum_struct_class)

        aggregate_failures do
          expect(result).to eq(expected_schema)
          expect(JSONSchemer).to be_valid_schema(
            result,
            meta_schema: 'http://json-schema.org/draft-06/schema#'
          )
        end
      end
    end

    context 'with hash types' do
      let(:inner_struct_class) do
        Class.new(T::Struct) do
          extend T::Sig

          const :inner_string, String, extra: { desc: 'String field inside InnerStruct' }
          const :inner_integer, Integer, extra: { desc: 'Integer field inside InnerStruct' }
        end
      end

      let(:hash_struct_class) do
        inner_struct_def = inner_struct_class
        Class.new(T::Struct) do
          extend T::Sig

          const :string_hash,
                T::Hash[String, String],
                extra: {
                  desc: 'A hash with string keys and values'
                }
          const :symbol_hash,
                T::Hash[Symbol, Integer],
                extra: {
                  desc: 'A hash with symbol keys and integer values'
                }
          const :struct_hash,
                T::Hash[String, inner_struct_def],
                extra: {
                  desc: 'A hash with string keys and struct values'
                }
          const :nullable_hash,
                T.nilable(T::Hash[String, String]),
                extra: {
                  desc: 'A nullable hash'
                }
        end
      end

      let(:expected_schema) do
        {
          type: 'object',
          properties: {
            string_hash: {
              type: 'object',
              additionalProperties: {
                type: 'string'
              },
              description: 'A hash with string keys and values'
            },
            symbol_hash: {
              type: 'object',
              additionalProperties: {
                type: 'integer'
              },
              description: 'A hash with symbol keys and integer values'
            },
            struct_hash: {
              type: 'object',
              additionalProperties: {
                type: 'object',
                properties: {
                  inner_string: {
                    type: 'string',
                    description: 'String field inside InnerStruct'
                  },
                  inner_integer: {
                    type: 'integer',
                    description: 'Integer field inside InnerStruct'
                  }
                },
                required: %w[inner_string inner_integer],
                additionalProperties: false
              },
              description: 'A hash with string keys and struct values'
            },
            nullable_hash: {
              'anyOf' => [
                { type: 'object', additionalProperties: { type: 'string' } },
                { type: 'null' }
              ],
              :description => 'A nullable hash'
            }
          },
          required: %w[string_hash symbol_hash struct_hash nullable_hash],
          additionalProperties: false
        }.deep_stringify_keys
      end

      # There are very flaky: you cannot use strict key and often missed in response
      it 'generates a valid JSON Schema with hash types' do
        result = described_class.convert(hash_struct_class, accept_flaky_hash: true)

        aggregate_failures do
          expect(result).to eq(expected_schema)
          expect(JSONSchemer).to be_valid_schema(
            result,
            meta_schema: 'http://json-schema.org/draft-06/schema#'
          )
        end
      end
    end
  end
end
