# typed: strict

require 'json'
require 'active_support/inflector'

module Ai
  # Utility class that converts a JSON-Schema string into a +T::Struct+ Ruby
  # class definition.
  #
  # The resulting definition is returned as a *string* so that it can be
  # injected into ERB templates when auto-generating files.
  class SchemaToStructString
    extend T::Sig

    sig { params(schema: String, class_name: String).returns(String) }
    def self.convert(schema, class_name: 'Input')
      new(schema, class_name: class_name).convert
    end

    sig { params(schema: String, class_name: String).void }
    def initialize(schema, class_name: 'Input')
      @schema = schema
      @root_class_name = class_name
      @generated_classes = T.let(Set.new, T::Set[String])
      @nested_definitions = T.let([], T::Array[String])
      @schema_definitions = T.let({}, T::Hash[String, T::Hash[String, T.untyped]]) # rubocop:disable Sorbet/ForbidTUntyped
      @resolved_refs = T.let({}, T::Hash[String, T::Hash[String, T.untyped]]) # rubocop:disable Sorbet/ForbidTUntyped
    end

    sig { returns(String) }
    def convert
      main_definition = generate_struct(parsed_schema, @root_class_name)
      (@nested_definitions + [main_definition]).join("\n\n")
    end

    sig { returns(T::Hash[String, T.untyped]) } # rubocop:disable Sorbet/ForbidTUntyped
    def parsed_schema
      return @parsed_schema if @parsed_schema

      full_schema = T.let(JSON.parse(@schema), T::Hash[String, T.untyped]) # rubocop:disable Sorbet/ForbidTUntyped

      if full_schema.key?('json')
        @parsed_schema = T.let(full_schema['json'], T.nilable(T::Hash[String, T.untyped])) # rubocop:disable Sorbet/ForbidTUntyped
      elsif full_schema.key?('$defs') || full_schema.key?('definitions')
        @schema_definitions = full_schema['$defs'] || full_schema['definitions'] || {}
        @parsed_schema = full_schema
      else
        @parsed_schema = full_schema
      end

      @parsed_schema || {}
    rescue JSON::ParserError => e
      raise ArgumentError, "Invalid JSON schema provided: #{e.message}"
    end

    # rubocop:disable Sorbet/ForbidTUntyped
    sig do
      params(schema_hash: T::Hash[T.any(Symbol, String), T.untyped]).returns(
        T::Hash[T.any(Symbol, String), T.untyped]
      )
    end
    # rubocop:enable Sorbet/ForbidTUntyped
    def resolve_ref(schema_hash)
      ref = schema_hash['$ref']
      return schema_hash unless ref

      return T.must(@resolved_refs[ref]) if @resolved_refs.key?(ref)

      resolved =
        if ref.start_with?('#/$defs/', '#/definitions/')
          ref_name = ref.split('/').last
          @schema_definitions[ref_name]
        elsif ref.start_with?('#/')
          parts = ref.split('/')[1..]
          navigate_schema_path(parsed_schema, parts)
        elsif ref.match?(%r{\A\d+/})
          parts = ref.split('/')
          path_parts = parts[1..]
          navigate_schema_path(parsed_schema, path_parts)
        else
          parts = ref.split('/')
          navigate_schema_path(parsed_schema, parts)
        end

      return schema_hash unless resolved

      @resolved_refs[ref] = T.cast(resolved, T::Hash[String, T.untyped]) # rubocop:disable Sorbet/ForbidTUntyped
      resolved
    end

    sig do
      params(
        schema: T.untyped, # rubocop:disable Sorbet/ForbidTUntyped
        parts: T::Array[String]
      ).returns(T.nilable(T::Hash[T.any(Symbol, String), T.untyped])) # rubocop:disable Sorbet/ForbidTUntyped
    end
    def navigate_schema_path(schema, parts)
      current = T.let(schema, T.untyped) # rubocop:disable Sorbet/ForbidTUntyped

      parts.each_with_index do |part, _index|
        return nil if current.nil?

        case current
        when Hash
          current =
            if current['properties']&.[](part)
              current['properties'][part]
            elsif part == 'items' && current['items']
              current['items']
            elsif part == 'properties' && current['properties']
              current['properties']
            elsif current[part]
              current[part]
            else
              return nil
            end
        when Array
          return nil unless part.match?(/\A\d+\z/)

          index_val = part.to_i
          current = current[index_val] if current.size > index_val
        else
          return nil
        end
      end

      current.is_a?(Hash) ? current : nil
    end

    sig do
      params(
        schema_hash: T::Hash[T.any(Symbol, String), T.untyped], # rubocop:disable Sorbet/ForbidTUntyped
        class_name: String,
        depth: Integer
      ).returns(String)
    end
    def generate_struct(schema_hash, class_name, depth = 0)
      properties = T.let(schema_hash.fetch('properties', {}), T::Hash[String, T.untyped]) # rubocop:disable Sorbet/ForbidTUntyped
      required = T.let(schema_hash.fetch('required', []), T::Array[String])

      lines = []
      lines << "class #{class_name} < T::Struct"

      properties.each do |prop_name, prop_schema|
        prop_type = sorbet_type(prop_name, prop_schema, depth)
        prop_type = "T.nilable(#{prop_type})" unless required.include?(prop_name) ||
          prop_type == 'T.untyped'

        comment = build_comment(prop_schema)
        lines << "  #{comment}" if comment
        lines << "  const :#{prop_name}, #{prop_type}"
      end

      lines << 'end'
      lines.join("\n")
    end

    sig do
      params(
        prop_name: T.any(Symbol, String),
        prop_schema: T::Hash[T.any(Symbol, String), T.untyped], # rubocop:disable Sorbet/ForbidTUntyped
        depth: Integer
      ).returns(String)
    end
    def sorbet_type(prop_name, prop_schema, depth) # rubocop:disable Metrics/CyclomaticComplexity
      resolved_schema = resolve_ref(prop_schema)
      type = T.unsafe(resolved_schema['type'] || resolved_schema[:type]) # rubocop:disable Sorbet/ForbidTUnsafe

      if type.is_a?(Array)
        non_null = type.reject { |t| t == 'null' }
        ruby_types =
          non_null
            .map { |t| sorbet_type(prop_name, resolved_schema.merge('type' => t), depth) }
            .uniq
        return "T.any(#{ruby_types.join(', ')})"
      end

      case type
      when 'string'
        return 'Time' if resolved_schema['format'] == 'date-time'
        return 'String' unless resolved_schema.key?('enum')

        enum_class_name = "#{prop_name.to_s.camelize}Enum"
        return enum_class_name if @generated_classes.include?(enum_class_name)

        @nested_definitions << generate_enum(enum_class_name, resolved_schema['enum'])
        @generated_classes.add(enum_class_name)
        enum_class_name
      when 'integer'
        'Integer'
      when 'number'
        'Float'
      when 'boolean'
        'T::Boolean'
      when 'null'
        'NilClass'
      when 'array'
        raw_items = resolved_schema['items'] || resolved_schema[:items] || {}

        if raw_items.is_a?(Array)
          tuple_types =
            raw_items.map.with_index do |schema, idx|
              sorbet_type("#{prop_name.to_s.singularize}_#{idx}", schema, depth + 1)
            end
          "T::Array[T.any(#{tuple_types.join(', ')})]"
        else
          items = T.cast(raw_items, T::Hash[T.any(Symbol, String), T.untyped]) # rubocop:disable Sorbet/ForbidTUntyped
          "T::Array[#{sorbet_type(prop_name.to_s.singularize, items, depth + 1)}]"
        end
      when 'object'
        nested_class_name = prop_name.to_s.camelize
        return nested_class_name if @generated_classes.include?(nested_class_name)

        definition = generate_struct(resolved_schema, nested_class_name, depth + 1)
        if depth + 1 > 1
          @nested_definitions.unshift(definition)
        else
          @nested_definitions << definition
        end
        @generated_classes.add(nested_class_name)
        nested_class_name
      else
        'T.untyped'
      end
    end

    sig { params(class_name: String, values: T::Array[String]).returns(String) }
    def generate_enum(class_name, values)
      lines = []
      lines << "class #{class_name} < T::Enum"
      lines << '  enums do'
      values.each do |val|
        const_name = val.to_s.gsub(/[^A-Za-z0-9]+/, '_').camelize
        lines << "    #{const_name} = new('#{val}')"
      end
      lines << '  end'
      lines << 'end'
      lines.join("\n")
    end

    sig { params(prop_schema: T::Hash[String, T.untyped]).returns(T.nilable(String)) } # rubocop:disable Sorbet/ForbidTUntyped
    def build_comment(prop_schema)
      keys_in_order = %w[
        minLength
        maxLength
        exclusiveMinimum
        exclusiveMaximum
        minItems
        maxItems
        format
        const
        default
      ]
      entries =
        keys_in_order.filter_map do |k|
          next unless prop_schema.key?(k)

          val = prop_schema[k]
          formatted_val =
            if val.is_a?(String) && %w[const default].include?(k)
              "\"#{val}\""
            else
              val
            end
          "#{k}: #{formatted_val}"
        end

      return nil if entries.empty?

      "# #{entries.join(', ')}"
    end
  end
end
