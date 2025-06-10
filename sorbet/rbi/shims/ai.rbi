# typed: true

module Ai
  sig { returns(Ai::Client) }
  def self.client
  end

  sig { params(client: Ai::Client).void }
  def self.client=(client)
  end

  sig { returns(String) }
  def self.endpoint
  end

  sig { params(endpoint: String).void }
  def self.endpoint=(endpoint)
  end

  sig { returns(String) }
  def self.origin
  end

  sig { params(origin: String).void }
  def self.origin=(origin)
  end
end
