# typed: strict

require 'erb'
require 'fileutils'
require 'active_support/inflector'

module Ai
  module Utils
    class AgentGenerator
      extend T::Sig

      sig { params(agent_name: String, force: T::Boolean).void }
      def self.generate(agent_name, force: false)
        new(agent_name, force: force).generate
      end

      sig { returns(String) }
      attr_reader :agent_name

      sig { returns(T::Boolean) }
      attr_reader :force

      sig { params(agent_name: String, force: T::Boolean).void }
      def initialize(agent_name, force: false)
        @agent_name = T.let(agent_name, String)
        @force = T.let(force, T::Boolean)
      end

      sig { void }
      def generate
        validate_agent_name!

        content = render_template
        target_path = agent_file_path

        ensure_agents_directory_exists
        write_agent_file(target_path, content)
      end

      private

      sig { void }
      def validate_agent_name!
        if agent_name.empty? || agent_name.strip.empty?
          raise ArgumentError, 'Agent name cannot be empty'
        end

        return if agent_name.match?(/\A[a-zA-Z_][a-zA-Z0-9_]*\z/)
        raise ArgumentError, "Agent name must be a valid Ruby identifier: #{agent_name}"
      end

      sig { returns(String) }
      def render_template
        template_path = File.expand_path('../templates/agent.rb.erb', __FILE__)
        template_content = File.read(template_path)
        erb = ERB.new(template_content)
        erb.result(binding)
      end

      sig { returns(String) }
      def agent_file_path
        agents_dir = File.expand_path('../../agents', __FILE__)
        "#{agents_dir}/#{agent_name.underscore}.rb"
      end

      sig { void }
      def ensure_agents_directory_exists
        agents_dir = File.expand_path('../agents', __FILE__)
        FileUtils.mkdir_p(agents_dir)
      end

      sig { params(path: String, content: String).void }
      def write_agent_file(path, content)
        raise ArgumentError, "Agent file already exists: #{path}" if File.exist?(path) && !force

        File.write(path, content)
        puts "Generated agent file: #{path}"
      end
    end
  end
end
