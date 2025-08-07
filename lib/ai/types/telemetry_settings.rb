# typed: strict

module Ai
  class TelemetrySettings < T::Struct
    extend T::Sig

    # Enable or disable telemetry. Enabled by default.
    const :enabled, T::Boolean, default: true

    # Enable or disable input recording. You might want to disable this to avoid 
    # recording sensitive information, reduce data transfers, or increase performance.
    const :record_inputs, T::Boolean, default: false

    # Enable or disable output recording. You might want to disable this to avoid 
    # recording sensitive information, reduce data transfers, or increase performance.
    const :record_outputs, T::Boolean, default: false

    # Identifier for this function. Used to group telemetry data by function.
    const :function_id, T.nilable(String), default: nil

    # Additional information to include in the telemetry data. 
    # AttributeValue can be string, number, boolean, array of these types, or null.
    const :metadata, T::Hash[String, T.anything], default: {}

    # Custom OpenTelemetry tracer instance to use for the telemetry data.
    # Note: In Ruby implementation, this would typically be configured at the client level
    const :tracer, T.nilable(T.anything), default: nil

    # Override as_json to automatically convert enabled to is_enabled for API compatibility  
    sig { returns(T::Hash[String, T.anything]) }
    def as_json
      serialize.tap do |hash|
        hash['is_enabled'] = hash.delete('enabled')
      end
    end
  end
end 