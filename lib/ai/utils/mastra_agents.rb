# typed: strict

require 'net/http'
require 'json'

module Ai
  module Utils
    class MastraAgents
      extend T::Sig

      sig { returns(T::Array[String]) }
      def self.all
        url = "#{ENV.fetch('MASTRA_LOCATION')}/api/agents"
        response = Net::HTTP.get(URI(url))
        JSON.parse(response).keys
      end
    end
  end
end
