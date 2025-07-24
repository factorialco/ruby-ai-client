# typed: strict
# frozen_string_literal: true

RSpec.describe Ai::TelemetrySettings do
  describe 'initialization' do
    context 'with defaults' do
      subject { described_class.new }

      it 'sets correct default values' do
        expect(subject.enabled).to be true
        expect(subject.record_inputs).to be false
        expect(subject.record_outputs).to be false
        expect(subject.function_id).to be_nil
        expect(subject.metadata).to eq({})
        expect(subject.tracer).to be_nil
      end
    end

    context 'with custom values' do
      subject do
        described_class.new(
          enabled: true,
          record_inputs: false,
          record_outputs: false,
          function_id: 'my-custom-function',
          metadata: { 'agent.name' => 'test-agent', 'service.version' => '1.0.0' },
          tracer: 'custom-tracer'
        )
      end

      it 'sets custom values correctly' do
        expect(subject.enabled).to be true
        expect(subject.record_inputs).to be false
        expect(subject.record_outputs).to be false
        expect(subject.function_id).to eq('my-custom-function')
        expect(subject.metadata).to eq({ 'agent.name' => 'test-agent', 'service.version' => '1.0.0' })
        expect(subject.tracer).to eq('custom-tracer')
      end
    end
  end

  describe 'privacy and security configurations' do
    it 'allows disabling input recording for sensitive data' do
      settings = described_class.new(
        enabled: true,
        record_inputs: false,
        record_outputs: true
      )

      expect(settings.enabled).to be true
      expect(settings.record_inputs).to be false
      expect(settings.record_outputs).to be true
    end

    it 'allows disabling output recording for sensitive data' do
      settings = described_class.new(
        enabled: true,
        record_inputs: true,
        record_outputs: false
      )

      expect(settings.enabled).to be true
      expect(settings.record_inputs).to be true
      expect(settings.record_outputs).to be false
    end

    it 'allows disabling both inputs and outputs' do
      settings = described_class.new(
        enabled: true,
        record_inputs: false,
        record_outputs: false
      )

      expect(settings.enabled).to be true
      expect(settings.record_inputs).to be false
      expect(settings.record_outputs).to be false
    end
  end

  describe 'agent identification metadata' do
    it 'supports agent identification in metadata' do
      settings = described_class.new(
        enabled: true,
        function_id: 'agent-marvin-conversation',
        metadata: {
          'agent.name' => 'marvin',
          'service.name' => 'mastra',
          'service.namespace' => 'meetings',
          'cx.application.name' => 'ai-tracing',
          'cx.subsystem.name' => 'mastra-agents'
        }
      )

      expect(settings.metadata['agent.name']).to eq('marvin')
      expect(settings.metadata['service.name']).to eq('mastra')
      expect(settings.metadata['service.namespace']).to eq('meetings')
      expect(settings.metadata['cx.application.name']).to eq('ai-tracing')
      expect(settings.metadata['cx.subsystem.name']).to eq('mastra-agents')
    end
  end
end 