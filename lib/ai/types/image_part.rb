# typed: strict

require 'base64'

module Ai
  class ImagePart < T::Struct
    extend T::Sig

    const :type, String, default: 'image'
    const :image_data, T.nilable(String), default: nil
    const :image_url, T.nilable(String), default: nil
    const :media_type, String

    sig do
      params(
        media_type: String,
        type: String,
        image_data: T.nilable(String),
        image_url: T.nilable(String)
      ).void
    end
    def initialize(media_type:, type: 'image', image_data: nil, image_url: nil)
      super
      validate!
    end

    sig { returns(T::Hash[Symbol, String]) }
    def as_json
      image_value =
        if image_url
          T.must(image_url)
        else
          encoded = Base64.strict_encode64(T.must(image_data).b)
          "data:#{media_type};base64,#{encoded}"
        end

      { type: type, image: image_value, mediaType: media_type }
    end

    private

    sig { void }
    def validate!
      if image_data.nil? && image_url.nil?
        raise ArgumentError, "Either image_data or image_url must be provided"
      end

      return unless !image_data.nil? && !image_url.nil?

      raise ArgumentError, "Cannot provide both image_data and image_url"
    end
  end
end
