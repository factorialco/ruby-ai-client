# typed: strict

require 'tempfile'
require 'tmpdir'
require_relative '../lib/ai/utils/agent_generator'

RSpec.describe Ai::Utils::AgentGenerator do
  let(:agent_name) { 'test_agent' }
  let(:generator) { described_class.new(agent_name) }

  describe '#initialize' do
    it 'sets agent_name and force attributes' do
      generator = described_class.new('my_agent', force: true)

      expect(generator.agent_name).to eq('my_agent')
      expect(generator.force).to be true
    end

    it 'defaults force to false' do
      generator = described_class.new('my_agent')

      expect(generator.force).to be false
    end
  end

  describe '#generate' do
    let(:temp_dir) { Dir.mktmpdir }
    let(:agents_dir) { File.join(temp_dir, 'agents') }
    let(:target_file) { File.join(agents_dir, 'test_agent.rb') }

    before do
      # Mock the file paths to use temp directory
      allow(File).to receive(:expand_path).and_call_original
      allow(File).to receive(:expand_path).with('../../agents', anything).and_return(agents_dir)
      allow(File).to receive(:expand_path).with('../agents', anything).and_return(agents_dir)
      allow(FileUtils).to receive(:mkdir_p).with(agents_dir).and_call_original
    end

    after { FileUtils.rm_rf(temp_dir) }

    it 'generates agent file successfully' do
      expect { generator.generate }.to output(/Generated agent file/).to_stdout

      expect(File.exist?(target_file)).to be true
      content = File.read(target_file)
      expect(content).to include('class TestAgent')
      expect(content).to include('def self.agent_name')
      expect(content).to include('"test_agent"')
    end

    it 'creates agents directory if it does not exist' do
      expect(FileUtils).to receive(:mkdir_p).with(agents_dir)

      generator.generate
    end

    it 'raises error if file exists and force is false' do
      # Create the file first
      FileUtils.mkdir_p(agents_dir)
      File.write(target_file, 'existing content')

      expect { generator.generate }.to raise_error(ArgumentError, /Agent file already exists/)
    end

    it 'overwrites file if force is true' do
      # Create the file first
      FileUtils.mkdir_p(agents_dir)
      File.write(target_file, 'existing content')

      generator_with_force = described_class.new(agent_name, force: true)
      expect { generator_with_force.generate }.to output(/Generated agent file/).to_stdout

      content = File.read(target_file)
      expect(content).to include('class TestAgent')
      expect(content).not_to include('existing content')
    end
  end

  describe 'agent name validation' do
    context 'with valid agent names' do
      %w[agent test_agent MyAgent _private Agent123 agent_with_numbers].each do |valid_name|
        it "accepts #{valid_name}" do
          expect { described_class.new(valid_name).send(:validate_agent_name!) }.not_to raise_error
        end
      end
    end

    context 'with invalid agent names' do
      it 'raises error for empty name' do
        generator = described_class.new('')
        expect { generator.send(:validate_agent_name!) }.to raise_error(
          ArgumentError,
          /cannot be empty/
        )
      end

      it 'raises error for whitespace-only name' do
        generator = described_class.new('   ')
        expect { generator.send(:validate_agent_name!) }.to raise_error(
          ArgumentError,
          /cannot be empty/
        )
      end

      %w[123agent agent-name agent.name agent\ name agent@name].each do |invalid_name|
        it "rejects #{invalid_name}" do
          generator = described_class.new(invalid_name)
          expect { generator.send(:validate_agent_name!) }.to raise_error(
            ArgumentError,
            /valid Ruby identifier/
          )
        end
      end
    end
  end

  describe '#render_template' do
    it 'renders the ERB template with agent name' do
      content = generator.send(:render_template)

      expect(content).to include('# typed: strict')
      expect(content).to include('module Ai')
      expect(content).to include('module Agents')
      expect(content).to include('class TestAgent')
      expect(content).to include('def self.agent_name')
      expect(content).to include('"test_agent"')
      expect(content).to include('def self.generate_text')
    end

    it 'properly classifies agent name' do
      generator = described_class.new('my_custom_agent')
      content = generator.send(:render_template)

      expect(content).to include('class MyCustomAgent')
      expect(content).to include('"my_custom_agent"')
    end

    it 'handles single word agent names' do
      generator = described_class.new('user')
      content = generator.send(:render_template)

      expect(content).to include('class User')
      expect(content).to include('"user"')
    end

    it 'raises error if template file does not exist' do
      allow(File).to receive(:expand_path).with('../templates/agent.rb.erb', anything).and_return(
        '/nonexistent/path'
      )
      allow(File).to receive(:read).with('/nonexistent/path').and_raise(Errno::ENOENT)

      expect { generator.send(:render_template) }.to raise_error(Errno::ENOENT)
    end
  end

  describe '#agent_file_path' do
    it 'returns correct file path for simple agent name' do
      generator = described_class.new('user')

      # Mock the agents directory path
      allow(File).to receive(:expand_path).with('../../agents', anything).and_return(
        '/path/to/agents'
      )

      path = generator.send(:agent_file_path)
      expect(path).to eq('/path/to/agents/user.rb')
    end

    it 'returns correct file path for underscored agent name' do
      generator = described_class.new('my_custom_agent')

      # Mock the agents directory path
      allow(File).to receive(:expand_path).with('../../agents', anything).and_return(
        '/path/to/agents'
      )

      path = generator.send(:agent_file_path)
      expect(path).to eq('/path/to/agents/my_custom_agent.rb')
    end

    it 'converts CamelCase to underscore' do
      generator = described_class.new('MyCustomAgent')

      # Mock the agents directory path
      allow(File).to receive(:expand_path).with('../../agents', anything).and_return(
        '/path/to/agents'
      )

      path = generator.send(:agent_file_path)
      expect(path).to eq('/path/to/agents/my_custom_agent.rb')
    end
  end

  describe 'integration test' do
    let(:temp_dir) { Dir.mktmpdir }
    let(:agents_dir) { File.join(temp_dir, 'agents') }

    before do
      # Mock the file paths to use temp directory
      allow(File).to receive(:expand_path).and_call_original
      allow(File).to receive(:expand_path).with('../../agents', anything).and_return(agents_dir)
      allow(File).to receive(:expand_path).with('../agents', anything).and_return(agents_dir)
    end

    after { FileUtils.rm_rf(temp_dir) }

    it 'generates a complete, valid agent file' do
      described_class.generate('email_sender')

      agent_file = File.join(agents_dir, 'email_sender.rb')
      expect(File.exist?(agent_file)).to be true

      content = File.read(agent_file)

      # Verify structure
      expect(content).to match(/# typed: strict/)
      expect(content).to match(/module Ai/)
      expect(content).to match(/module Agents/)
      expect(content).to match(/class EmailSender/)
      expect(content).to match(/extend T::Sig/)

      # Verify methods
      expect(content).to match(/def self\.agent_name/)
      expect(content).to match(/"email_sender"/)
      expect(content).to match(/def self\.\[\]\(output_class\)/)
      expect(content).to match(/def self\.generate_text/)

      # Verify proper Ruby syntax (basic check)
      expect(content).to match(/end\s*\z/) # File should end with 'end'
    end

    it 'handles complex agent names correctly' do
      described_class.generate('my_complex_agent_name_123')

      agent_file = File.join(agents_dir, 'my_complex_agent_name_123.rb')
      expect(File.exist?(agent_file)).to be true

      content = File.read(agent_file)
      expect(content).to include('class MyComplexAgentName123')
      expect(content).to include('"my_complex_agent_name_123"')
    end
  end
end
