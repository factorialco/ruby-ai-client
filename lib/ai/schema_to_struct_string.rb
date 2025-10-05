# typed: strict
# rubocop:disable Sorbet/ForbidTUntyped

require 'json'
require 'active_support/inflector'

module Ai
  # Utility class that converts a JSON-Schema string into a +T::Struct+ Ruby
  # class definition.
  #
  # The resulting definition is returned as a *string* so that it can be
  # injected into ERB templates when auto-generating files.
  #
  # Note: This class uses T.untyped for JSON schema structures as they are
  # inherently dynamic and come from external sources. Type safety is maintained
  # through runtime checks and the generated output is fully typed.
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
      @schema_definitions = T.let({}, T::Hash[String, T::Hash[String, T.untyped]])
      @resolved_refs = T.let({}, T::Hash[String, T::Hash[String, T.untyped]])
      @dependencies = T.let({}, T::Hash[String, T::Set[String]])
      @current_class = T.let(nil, T.nilable(String))
    end

    sig { returns(String) }
    def convert
      main_definition = generate_struct(parsed_schema, @root_class_name)
      sorted_definitions = topological_sort(@nested_definitions)
      (sorted_definitions + [main_definition]).join("\n\n")
    end

    sig { returns(T::Hash[String, T.untyped]) }
    def parsed_schema
      return @parsed_schema if @parsed_schema

      full_schema = T.let(JSON.parse(@schema), T::Hash[String, T.untyped])

      if full_schema.key?('json')
        @parsed_schema = T.let(full_schema['json'], T.nilable(T::Hash[String, T.untyped]))
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

    sig do
      params(schema_hash: T::Hash[T.any(Symbol, String), T.untyped]).returns(
        T::Hash[T.any(Symbol, String), T.untyped]
      )
    end
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

      @resolved_refs[ref] = T.cast(resolved, T::Hash[String, T.untyped])
      resolved
    end

    sig do
      params(schema: T.untyped, parts: T::Array[String]).returns(
        T.nilable(T::Hash[T.any(Symbol, String), T.untyped])
      )
    end
    def navigate_schema_path(schema, parts)
      current = T.let(schema, T.untyped)

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
        schema_hash: T::Hash[T.any(Symbol, String), T.untyped],
        class_name: String,
        depth: Integer
      ).returns(String)
    end
    def generate_struct(schema_hash, class_name, depth = 0)
      properties = T.let(schema_hash.fetch('properties', {}), T::Hash[String, T.untyped])
      required = T.let(schema_hash.fetch('required', []), T::Array[String])

      previous_class = @current_class
      @current_class = class_name
      @dependencies[class_name] ||= Set.new

      lines = []
      lines << "class #{class_name} < T::Struct"

      properties.each do |prop_name, prop_schema|
        prop_type = sorbet_type(prop_name, prop_schema, depth)

        extract_class_dependencies(prop_type).each { |dep| add_dependency(dep) }

        unless required.include?(prop_name) || prop_type == 'T.untyped' ||
                 prop_type.start_with?('T.nilable(')
          prop_type = "T.nilable(#{prop_type})"
        end

        comment = build_comment(prop_schema)
        lines << "  #{comment}" if comment
        lines << "  const :#{prop_name}, #{prop_type}"
      end

      lines << 'end'

      @current_class = previous_class

      lines.join("\n")
    end

    sig do
      params(
        prop_name: T.any(Symbol, String),
        prop_schema: T::Hash[T.any(Symbol, String), T.untyped],
        depth: Integer
      ).returns(String)
    end
    def sorbet_type(prop_name, prop_schema, depth) # rubocop:disable Metrics/CyclomaticComplexity
      resolved_schema = resolve_ref(prop_schema)

      # Handle anyOf pattern for nullable types (e.g., from Zod's .nullable())
      any_of_value = resolved_schema['anyOf']
      if any_of_value.is_a?(Array)
        non_null_schemas = any_of_value.select { |s| s.is_a?(Hash) && s['type'] != 'null' }

        if non_null_schemas.length == 1 && non_null_schemas.length < any_of_value.length
          # It's a nullable type: anyOf with exactly one non-null type
          first_schema = T.cast(non_null_schemas.first, T::Hash[T.any(Symbol, String), T.untyped])
          inner_type = sorbet_type(prop_name, first_schema, depth)
          return "T.nilable(#{inner_type})"
        elsif non_null_schemas.length > 1
          # Multiple non-null types in union
          ruby_types =
            non_null_schemas
              .map do |schema|
                sorbet_type(
                  prop_name,
                  T.cast(schema, T::Hash[T.any(Symbol, String), T.untyped]),
                  depth
                )
              end
              .uniq
          base_type = "T.any(#{ruby_types.join(', ')})"
          has_null = any_of_value.any? { |s| s.is_a?(Hash) && s['type'] == 'null' }
          return has_null ? "T.nilable(#{base_type})" : base_type
        end
      end

      # Get the type field, which can be a string or array
      type_value = resolved_schema['type'] || resolved_schema[:type]

      if type_value.is_a?(Array)
        non_null = type_value.reject { |t| t == 'null' }

        if non_null.length == 1 && non_null.length < type_value.length
          inner_type =
            sorbet_type(prop_name, resolved_schema.merge('type' => non_null.first), depth)
          return "T.nilable(#{inner_type})"
        elsif non_null.length > 1
          ruby_types =
            non_null
              .map { |t| sorbet_type(prop_name, resolved_schema.merge('type' => t), depth) }
              .uniq
          base_type = "T.any(#{ruby_types.join(', ')})"
          return non_null.length < type_value.length ? "T.nilable(#{base_type})" : base_type
        end
      end

      case type_value
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
          items = T.cast(raw_items, T::Hash[T.any(Symbol, String), T.untyped])
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

    sig { params(prop_schema: T::Hash[String, T.untyped]).returns(T.nilable(String)) }
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

    sig { params(type_string: String).returns(T::Set[String]) }
    def extract_class_dependencies(type_string)
      dependencies = Set.new

      type_string.scan(/(?<![T.])\b([A-Z][a-zA-Z0-9_]*(?:Enum)?)\b/) do |match|
        class_name = match[0]
        unless %w[String Integer Float Time Boolean NilClass Array Hash].include?(class_name)
          dependencies.add(class_name)
        end
      end

      dependencies
    end

    sig { params(dependency_class: String).void }
    def add_dependency(dependency_class)
      return unless @current_class

      @dependencies[@current_class] ||= Set.new
      T.must(@dependencies[@current_class]).add(dependency_class)
    end

    sig { params(definitions: T::Array[String]).returns(T::Array[String]) }
    def topological_sort(definitions)
      class_to_def = T.let({}, T::Hash[String, String])
      definitions.each do |defn|
        match = defn.match(/class\s+([A-Z][a-zA-Z0-9_]*)/)
        next unless match

        class_name = T.must(match[1])
        class_to_def[class_name] = defn
      end

      sorted = T.let([], T::Array[String])
      visited = T.let(Set.new, T::Set[String])
      visiting = T.let(Set.new, T::Set[String])

      visit = T.let(nil, T.nilable(T.proc.params(class_name: String).void))
      visit =
        lambda do |class_name|
          next if visited.include?(class_name)

          next if visiting.include?(class_name)

          visiting.add(class_name)

          deps = @dependencies[class_name] || Set.new
          deps.each { |dep| T.must(visit).call(dep) if class_to_def.key?(dep) }

          visiting.delete(class_name)
          visited.add(class_name)
          defn = class_to_def[class_name]
          sorted << defn if defn
        end

      class_to_def.keys.each { |class_name| visit.call(class_name) }

      sorted
    end
  end
end
# rubocop:enable Sorbet/ForbidTUntyped
