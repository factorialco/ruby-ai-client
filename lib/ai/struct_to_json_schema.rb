# typed: strict

module Ai
  class StructToJsonSchema
    extend T::Sig

    sig do
      params(struct_class: T.class_of(T::Struct), accept_flaky_hash: T::Boolean).returns(
        T::Hash[String, T.untyped] # rubocop:disable Sorbet/ForbidTUntyped
      )
    end
    def self.convert(struct_class, accept_flaky_hash: false)
      properties = {}
      required = []

      struct_class.props.each do |name, prop_metadata|
        next if prop_metadata.dig(:extra, :skip)

        type_object = prop_metadata.fetch(:type_object)
        schema_type = convert_type_to_schema(type_object, accept_flaky_hash:) || {} # for Sorbet sake

        if (decription = prop_metadata.dig(:extra, :desc))
          schema_type[:description] = decription
        end

        properties[name.to_sym] = schema_type
        required << name.to_s # All fields are required
      end

      {
        type: 'object',
        properties: properties,
        required: required,
        additionalProperties: false
      }.deep_stringify_keys
    end

    # sorbet is stubborn to say that it is nilabe, so accetping it for making it happy
    sig do
      params(type: T::Types::Base, accept_flaky_hash: T::Boolean).returns(
        T.nilable(T::Hash[T.any(Symbol, String), T.untyped]) # rubocop:disable Sorbet/ForbidTUntyped
      )
    end
    def self.convert_type_to_schema(type, accept_flaky_hash: false)
      case type
      when T::Types::Simple
        raw = type.raw_type
        if raw == String
          { type: 'string' }
        elsif raw == Integer
          { type: 'integer' }
        elsif raw == Float
          { type: 'number' }
        elsif [TrueClass, FalseClass, T::Boolean].include?(raw)
          { type: 'boolean' }
        elsif raw == NilClass
          { type: 'null' }
        elsif raw < T::Struct
          convert(raw, accept_flaky_hash:)
        elsif raw < T::Enum
          { type: 'string', enum: raw.values.map(&:serialize) }
        else
          raise "Unsupported simple type: #{raw}"
        end
      when T::Types::Union
        union_types = type.types
        # uniq to merge boolean types
        type_schemas = union_types.map { |t| convert_type_to_schema(t, accept_flaky_hash:) }.uniq
        if type_schemas.length == 1
          type_schemas.first
        else
          { 'anyOf' => type_schemas }
        end
      when T::Types::TypedArray
        element_type = type.type
        items_schema = convert_type_to_schema(element_type, accept_flaky_hash:)
        { type: 'array', items: items_schema }
      when T::Types::TypedHash
        unless accept_flaky_hash
          raise 'TypedHash is not supported due to OpenAI limitations for structured outputs'
        end

        key_type = T.cast(type.keys, T::Types::Simple).raw_type
        raise "Unsupported key type: #{key_type}" unless [String, Symbol].include?(key_type)

        value_type = type.values
        value_schema = convert_type_to_schema(value_type, accept_flaky_hash:)
        { type: 'object', additionalProperties: value_schema }
      else
        raise "Unsupported type: #{type.class} - #{type}"
      end
    end
  end
end
