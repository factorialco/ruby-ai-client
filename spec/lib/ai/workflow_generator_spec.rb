# typed: strict

require 'spec_helper'
require 'rails/generators'
require 'generators/ai/workflow_generator'

RSpec.describe Ai::Generators::WorkflowGenerator do
  subject(:generator) { described_class.new([], { all: true, endpoint: endpoint }) }

  let(:endpoint) { 'https://mastra.test' }

  # Regression: `workflow_names = workflow_names` made the right-hand side resolve
  # to the nil local being defined rather than to #workflow_names, so `--all`
  # always died with "undefined method `empty?' for nil" before reaching any
  # workflow. Stub the endpoint, not the generator, so the real method runs.
  describe '--all' do
    context 'when Mastra reports no workflows' do
      before do
        stub_request(:get, "#{endpoint}/api/workflows").to_return(status: 200, body: '{}')
      end

      it 'reports none found instead of raising on nil' do
        expect { generator.send(:generate_all_workflows) }.to output(
          /No workflows found/
        ).to_stdout
      end
    end

    context 'when Mastra reports workflows' do
      before do
        stub_request(:get, "#{endpoint}/api/workflows").to_return(
          status: 200,
          body: { alpha: {}, beta: {} }.to_json
        )
      end

      it 'reads the names off the response' do
        expect(generator.send(:workflow_names)).to eq(%w[alpha beta])
      end
    end
  end

  # The template includes Ai::Workflow, whose `call` is abstract. Sorbet rejects an
  # implementation that does not say `override.`, so generated files failed to
  # typecheck in the consumer until the template declared it.
  describe 'the generated template' do
    let(:template) { File.read('lib/generators/ai/templates/workflow.rb.erb') }

    it 'includes the workflow interface' do
      expect(template).to include('include Ai::Workflow')
    end

    it 'declares the implementation as override' do
      expect(template).to include('sig { override.params(input: Input,')
    end

    it 'forwards headers to the client' do
      expect(template).to include('input:, headers:')
    end
  end
end
