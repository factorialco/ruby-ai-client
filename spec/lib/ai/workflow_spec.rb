# typed: strict

require 'spec_helper'

RSpec.describe Ai::Workflow do
  # A stand-in for a generated `Ai::Workflows::*` class.
  let(:workflow) do
    Class.new do
      extend T::Sig
      include Ai::Workflow

      class << self
        def call(input, headers: {})
          Struct.new(:input, :headers).new(input, headers)
        end
      end
    end
  end

  it 'lets a caller accept a workflow class as a typed argument' do
    expect(workflow).to be < described_class
    expect(workflow.singleton_class).to be < described_class::ClassMethods
  end

  it 'forwards input and headers to the class method' do
    result = workflow.call({ value: 'x' }, headers: { 'X-Factorial-Actor-Id' => '42' })

    expect(result.input).to eq({ value: 'x' })
    expect(result.headers).to eq({ 'X-Factorial-Actor-Id' => '42' })
  end

  it 'defaults headers to an empty hash' do
    expect(workflow.call({ value: 'x' }).headers).to eq({})
  end

  # The point of the interface: a class that forgets `self.call` fails loudly
  # rather than silently doing nothing.
  it 'requires the including class to implement call' do
    incomplete = Class.new { include Ai::Workflow }

    expect { incomplete.call({}) }.to raise_error(NotImplementedError, /abstract/)
  end
end
