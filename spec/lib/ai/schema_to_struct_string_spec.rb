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

    it 'handles complex Zod schemas with circular references and enums' do
      # This schema mimics the structure from talentEngagementMeetingsChat workflow
      complex_schema = {
        'json' => {
          'type' => 'object',
          'properties' => {
            'currentMessage' => {
              'type' => 'object',
              'properties' => {
                'role' => {
                  'type' => 'string',
                  'enum' => %w[user assistant system],
                  'description' => 'Message role'
                },
                'content' => {
                  'type' => 'string',
                  'description' => 'Message content'
                }
              },
              'required' => %w[role content]
            },
            'directReports' => {
              'type' => 'array',
              'items' => {
                'type' => 'object',
                'properties' => {
                  'employeeId' => {
                    'type' => 'string'
                  },
                  'name' => {
                    'type' => 'string'
                  },
                  'position' => {
                    'type' => 'string'
                  },
                  'meetings' => {
                    'type' => 'array',
                    'items' => {
                      'type' => 'object',
                      'properties' => {
                        'id' => {
                          'type' => 'integer'
                        },
                        'date' => {
                          'type' => 'string'
                        }
                      },
                      'required' => %w[id date]
                    }
                  }
                },
                'required' => %w[employeeId name meetings]
              }
            },
            'cache' => {
              'type' => 'object',
              'properties' => {
                'directReports' => {
                  'type' => 'array',
                  'items' => {
                    'type' => 'object',
                    'properties' => {
                      'employeeId' => {
                        'type' => 'string'
                      },
                      'name' => {
                        'type' => 'string'
                      }
                    },
                    'required' => %w[employeeId name]
                  }
                }
              },
              'required' => ['directReports']
            }
          },
          'required' => ['currentMessage']
        }
      }.to_json

      result = converter.convert(complex_schema, class_name: 'ComplexInput')

      # Verify key aspects without full string matching
      expect(result).to include('class ComplexInput < T::Struct')
      expect(result).to include('class RoleEnum < T::Enum')
      expect(result).to include('User = new(\'user\')')
      expect(result).to include('Assistant = new(\'assistant\')')
      expect(result).to include('System = new(\'system\')')
      expect(result).to include('const :role, RoleEnum')
      expect(result).to include('const :content, String')
      expect(result).to include('T::Array[DirectReport]')
      expect(result).to include('T::Array[Meeting]')

      # Should not contain T.untyped anywhere
      expect(result).not_to include('T.untyped')
    end

    it 'handles schemas with optional properties correctly' do
      optional_schema = {
        'json' => {
          'type' => 'object',
          'properties' => {
            'required_field' => {
              'type' => 'string'
            },
            'optional_field' => {
              'type' => 'string'
            }
          },
          'required' => ['required_field']
        }
      }.to_json

      result = converter.convert(optional_schema, class_name: 'OptionalTest')

      expect(result).to include('const :required_field, String')
      expect(result).to include('const :optional_field, T.nilable(String)')
    end

    describe '$ref resolution patterns' do
      it 'resolves standard JSON Schema #/ references' do
        ref_schema = {
          'json' => {
            'type' => 'object',
            'properties' => {
              'user' => {
                'type' => 'object',
                'properties' => {
                  'name' => {
                    'type' => 'string'
                  },
                  'role' => {
                    'type' => 'string',
                    'enum' => %w[admin user]
                  }
                }
              },
              'current_user' => {
                '$ref' => '#/properties/user'
              }
            }
          }
        }.to_json

        result = converter.convert(ref_schema, class_name: 'StandardRef')

        expect(result).to include('class RoleEnum < T::Enum')
        expect(result).to include('Admin = new(\'admin\')')
        expect(result).to include('User = new(\'user\')')
        expect(result).not_to include('T.untyped')
      end

      it 'resolves Zod numeric prefix references like "4/directReports/items"' do
        ref_schema = {
          'json' => {
            'type' => 'object',
            'properties' => {
              'directReports' => {
                'type' => 'array',
                'items' => {
                  'type' => 'object',
                  'properties' => {
                    'employeeId' => {
                      'type' => 'string'
                    },
                    'name' => {
                      'type' => 'string'
                    }
                  },
                  'required' => %w[employeeId name]
                }
              },
              'cachedReports' => {
                'type' => 'array',
                'items' => {
                  '$ref' => '4/directReports/items'
                }
              }
            }
          }
        }.to_json

        result = converter.convert(ref_schema, class_name: 'ZodNumericRef')

        expect(result).to include('const :employeeId, String')
        expect(result).to include('const :name, String')
        expect(result).not_to include('T.untyped')
      end

      it 'resolves direct property path references' do
        ref_schema = {
          'json' => {
            'type' => 'object',
            'properties' => {
              'messageHistory' => {
                'type' => 'array',
                'items' => {
                  'type' => 'object',
                  'properties' => {
                    'content' => {
                      'type' => 'string'
                    },
                    'metadata' => {
                      'type' => 'string'
                    }
                  },
                  'required' => ['content']
                }
              },
              'currentMessage' => {
                'type' => 'object',
                'properties' => {
                  'content' => {
                    '$ref' => 'messageHistory/items/properties/content'
                  }
                },
                'required' => ['content']
              }
            }
          }
        }.to_json

        result = converter.convert(ref_schema, class_name: 'DirectPathRef')

        # Should resolve the reference properly (content is required in both places)
        expect(result).to include('const :content, String')
        expect(result).not_to include('T.untyped')
      end

      it 'handles complex nested references' do
        complex_ref_schema = {
          'json' => {
            'type' => 'object',
            'properties' => {
              'level1' => {
                'type' => 'object',
                'properties' => {
                  'level2' => {
                    'type' => 'array',
                    'items' => {
                      'type' => 'object',
                      'properties' => {
                        'status' => {
                          'type' => 'string',
                          'enum' => %w[active inactive pending]
                        }
                      }
                    }
                  }
                }
              },
              'reference_field' => {
                '$ref' => '#/properties/level1/properties/level2/items/properties/status'
              }
            }
          }
        }.to_json

        result = converter.convert(complex_ref_schema, class_name: 'ComplexRef')

        expect(result).to include('class StatusEnum < T::Enum')
        expect(result).to include('Active = new(\'active\')')
        expect(result).not_to include('T.untyped')
      end
    end

    describe 'nullable type handling' do
      it 'handles anyOf with null for nullable types (Zod .nullable())' do
        nullable_schema = {
          'json' => {
            'type' => 'object',
            'properties' => {
              'name' => {
                'anyOf' => [{ 'type' => 'string' }, { 'type' => 'null' }]
              }
            },
            'required' => ['name']
          }
        }.to_json

        result = converter.convert(nullable_schema, class_name: 'NullableTest')

        expect(result).to include('const :name, T.nilable(String)')
        expect(result).not_to include('T.untyped')
      end

      it 'handles type arrays with null for nullable types' do
        nullable_schema = {
          'json' => {
            'type' => 'object',
            'properties' => {
              'count' => {
                'type' => %w[integer null]
              }
            },
            'required' => ['count']
          }
        }.to_json

        result = converter.convert(nullable_schema, class_name: 'NullableTypeArray')

        expect(result).to include('const :count, T.nilable(Integer)')
      end

      it 'handles nullable nested objects' do
        nullable_nested_schema = {
          'json' => {
            'type' => 'object',
            'properties' => {
              'metadata' => {
                'anyOf' => [
                  {
                    'type' => 'object',
                    'properties' => {
                      'version' => {
                        'type' => 'string'
                      }
                    },
                    'required' => ['version']
                  },
                  { 'type' => 'null' }
                ]
              }
            },
            'required' => ['metadata']
          }
        }.to_json

        result = converter.convert(nullable_nested_schema, class_name: 'NullableNested')

        expect(result).to include('class Metadata < T::Struct')
        expect(result).to include('const :version, String')
        expect(result).to include('const :metadata, T.nilable(Metadata)')
        expect(result).not_to include('T.untyped')
      end

      it 'does not double-wrap nullable types' do
        nullable_optional_schema = {
          'json' => {
            'type' => 'object',
            'properties' => {
              'optional_nullable' => {
                'anyOf' => [{ 'type' => 'string' }, { 'type' => 'null' }]
              }
            },
            'required' => []
          }
        }.to_json

        result = converter.convert(nullable_optional_schema, class_name: 'NoDoubleWrap')

        # Should have T.nilable once, not T.nilable(T.nilable(...))
        expect(result).to include('const :optional_nullable, T.nilable(String)')
        expect(result).not_to match(/T\.nilable\(T\.nilable/)
      end
    end

    describe 'dependency sorting' do
      it 'sorts nested structs by dependency order' do
        dependency_schema = {
          'json' => {
            'type' => 'object',
            'properties' => {
              'report' => {
                'type' => 'object',
                'properties' => {
                  'employee' => {
                    'type' => 'object',
                    'properties' => {
                      'id' => {
                        'type' => 'string'
                      },
                      'name' => {
                        'type' => 'string'
                      }
                    },
                    'required' => %w[id name]
                  },
                  'meeting' => {
                    'type' => 'object',
                    'properties' => {
                      'id' => {
                        'type' => 'integer'
                      },
                      'employee_id' => {
                        'type' => 'string'
                      }
                    },
                    'required' => %w[id employee_id]
                  }
                },
                'required' => %w[employee meeting]
              }
            },
            'required' => ['report']
          }
        }.to_json

        result = converter.convert(dependency_schema, class_name: 'DependencyTest')

        # Employee and Meeting should come before Report
        employee_pos = result.index('class Employee < T::Struct')
        meeting_pos = result.index('class Meeting < T::Struct')
        report_pos = result.index('class Report < T::Struct')
        input_pos = result.index('class DependencyTest < T::Struct')

        expect(employee_pos).to be < report_pos
        expect(meeting_pos).to be < report_pos
        expect(report_pos).to be < input_pos
      end

      it 'sorts complex nested dependencies correctly' do
        complex_dependency_schema = {
          'json' => {
            'type' => 'object',
            'properties' => {
              'direct_reports' => {
                'type' => 'array',
                'items' => {
                  'type' => 'object',
                  'properties' => {
                    'employee_info' => {
                      'type' => 'object',
                      'properties' => {
                        'id' => {
                          'type' => 'string'
                        },
                        'name' => {
                          'type' => 'string'
                        }
                      },
                      'required' => %w[id name]
                    },
                    'meetings' => {
                      'type' => 'array',
                      'items' => {
                        'type' => 'object',
                        'properties' => {
                          'id' => {
                            'type' => 'integer'
                          }
                        },
                        'required' => ['id']
                      }
                    }
                  },
                  'required' => %w[employee_info meetings]
                }
              }
            },
            'required' => ['direct_reports']
          }
        }.to_json

        result = converter.convert(complex_dependency_schema, class_name: 'ComplexDep')

        # EmployeeInfo and Meeting should come before DirectReport
        employee_info_pos = result.index('class EmployeeInfo < T::Struct')
        meeting_pos = result.index('class Meeting < T::Struct')
        direct_report_pos = result.index('class DirectReport < T::Struct')

        expect(employee_info_pos).to be < direct_report_pos
        expect(meeting_pos).to be < direct_report_pos
      end
    end
  end
end
