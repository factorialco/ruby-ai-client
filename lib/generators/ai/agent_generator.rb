require 'rails/generators/base'
require 'erb'
require 'fileutils'
require 'active_support/inflector'
require 'net/http'
require 'json'
require 'uri'

module Ai
  module Generators
    class AgentGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      class_option :endpoint, type: :string, desc: 'Mastra API endpoint URL', required: false

      class_option :all, type: :boolean, default: false, desc: 'Generate all agents from Mastra'

      class_option :name, type: :string, desc: 'Name of the agent to generate', required: false

      class_option :force, type: :boolean, default: false, desc: 'Override existing files'

      class_option :output,
                   type: :string,
                   desc: 'Output directory for agent files',
                   default: 'app/generated/ai/agents'

      def generate_agents
        options[:all] ? generate_all_agents : generate_single_agent(options[:name])
      end

      private

      def generate_all_agents
        validate_endpoint!

        say 'Fetching agents from Mastra...', :green
        agent_names = fetch_agent_names

        if agent_names.empty?
          say 'No agents found. Exiting.', :yellow
          return
        end

        say "Found #{agent_names.length} agents: #{agent_names.join(', ')}", :blue

        generated_count = 0
        skipped_count = 0
        errors = []

        agent_names.each do |agent_name|
          say "Generating agent: #{agent_name}"
          create_agent_file(agent_name)
          generated_count += 1
        rescue ArgumentError => e
          if e.message.include?('already exists') && !options[:force]
            say "  ⚠️  Skipped #{agent_name} (file already exists)", :yellow
            skipped_count += 1
          else
            say "  ❌ Error generating #{agent_name}: #{e.message}", :red
            errors << "#{agent_name}: #{e.message}"
          end
        rescue StandardError => e
          say "  ❌ Unexpected error generating #{agent_name}: #{e.message}", :red
          errors << "#{agent_name}: #{e.message}"
        end

        if errors.any?
          say "❌ Errors: #{errors.length}", :red
          say "\nErrors:"
          errors.each { |error| say "  - #{error}", :red }
          exit 1
        end
      end

      def generate_single_agent(agent_name)
        validate_agent_name!(agent_name)
        create_agent_file(agent_name)
      end

      def create_agent_file(agent_name)
        validate_agent_name!(agent_name)

        target_path = File.join(output_directory, "#{agent_name.underscore}.rb")

        if File.exist?(target_path) && !options[:force]
          raise ArgumentError, "Agent file already exists: #{target_path}"
        end

        directory_path = File.dirname(target_path)
        empty_directory directory_path unless Dir.exist?(directory_path)

        template_content = render_agent_template(agent_name)
        create_file target_path, template_content
      end

      def render_agent_template(agent_name)
        template_path = File.join(self.class.source_root, 'agent.rb.erb')
        template_content = File.read(template_path)
        erb = ERB.new(template_content)

        # Make agent_name available to the template
        @agent_name = agent_name
        erb.result(binding)
      end

      def validate_agent_name!(agent_name)
        if agent_name.empty? || agent_name.strip.empty?
          raise ArgumentError, 'Agent name cannot be empty'
        end

        return if agent_name.match?(/\A[a-zA-Z_][a-zA-Z0-9_]*\z/)
        raise ArgumentError, "Agent name must be a valid Ruby identifier: #{agent_name}"
      end

      def validate_endpoint!
        if options[:endpoint].to_s.empty? && ENV['MASTRA_LOCATION'].to_s.empty?
          raise ArgumentError,
                'Mastra API URL is required. Use --endpoint to specify it or set the MASTRA_LOCATION environment variable'
        end
      end

      def fetch_agent_names
        validate_endpoint!
        Ai.config.endpoint = options[:endpoint]
        Ai.config.client.agent_names
      end

      def output_directory
        if defined?(Rails) && Rails.respond_to?(:root)
          Rails.root.join(options[:output]).to_s
        else
          File.expand_path(options[:output])
        end
      end
    end
  end
end
