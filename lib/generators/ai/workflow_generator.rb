require 'rails/generators/base'
require 'erb'
require 'fileutils'
require 'active_support/inflector'
require 'set'
require 'ai/schema_to_struct_string'
require 'net/http'
require 'json'
require 'uri'
require 'ai/clients/mastra'

# WARNING: Keep this generator in sync with AgentGenerator where relevant!
module Ai
  module Generators
    # Generates Ruby workflow wrapper classes from Mastra workflow definitions.
    #
    # Usage examples:
    #
    #   # Generate a single workflow
    #   bin/rails generate ai:workflow --name="testWorkflow"
    #
    #   # Generate *all* workflows present in the Mastra instance
    #   bin/rails generate ai:workflow --all
    #
    # Command-line options mirror those of +AgentGenerator+ for consistency.
    class WorkflowGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      class_option :endpoint, type: :string, desc: 'Mastra API endpoint URL', required: false
      class_option :all, type: :boolean, default: false, desc: 'Generate all workflows from Mastra'
      class_option :name, type: :string, desc: 'Name of the workflow to generate', required: false
      class_option :force, type: :boolean, default: false, desc: 'Override existing files'
      class_option :output,
                   type: :string,
                   desc: 'Output directory for workflow files',
                   default: 'app/generated/ai/workflows'

      def generate_workflows
        options[:all] ? generate_all_workflows : generate_single_workflow(options[:name])
      end

      private

      ####################################
      # Public high-level generation paths
      ####################################

      def generate_all_workflows
        validate_endpoint!

        say 'Fetching workflows from Mastra...', :green
        workflow_names = fetch_workflow_names
        if workflow_names.empty?
          say 'No workflows found. Exiting.', :yellow
          return
        end

        workflow_names = workflow_names.compact.reject { |n| n.to_s.strip.empty? }
        say "Found #{workflow_names.length} workflows: #{workflow_names.join(', ')}", :blue

        generated_count = 0
        skipped_count = 0
        errors = []

        workflow_names.each do |workflow_name|
          say "Generating workflow: #{workflow_name}"
          create_workflow_file(workflow_name)
          generated_count += 1
        rescue ArgumentError => e
          if e.message.include?('already exists') && !options[:force]
            say "  ⚠️  Skipped #{workflow_name} (file already exists)", :yellow
            skipped_count += 1
          else
            say "  ❌ Error generating #{workflow_name}: #{e.message}", :red
            errors << "#{workflow_name}: #{e.message}"
          end
        rescue StandardError => e
          say "  ❌ Unexpected error generating #{workflow_name}: #{e.message}", :red
          errors << "#{workflow_name}: #{e.message}"
        end

        if errors.any?
          say "❌ Errors: #{errors.length}", :red
          say "\nErrors:"
          errors.each { |error| say "  - #{error}", :red }
          exit 1
        end
      end

      def generate_single_workflow(workflow_name)
        validate_workflow_name!(workflow_name)
        create_workflow_file(workflow_name)
      end

      ################################
      # Support/utility helper methods
      ################################

      def create_workflow_file(workflow_name)
        validate_workflow_name!(workflow_name)

        target_path = File.join(output_directory, "#{workflow_name.underscore}.rb")

        if File.exist?(target_path) && !options[:force]
          raise ArgumentError, "Workflow file already exists: #{target_path}"
        end

        directory_path = File.dirname(target_path)
        empty_directory directory_path unless Dir.exist?(directory_path)

        template_content = render_workflow_template(workflow_name)
        create_file target_path, template_content
      end

      def render_workflow_template(workflow_name)
        template_path = File.join(self.class.source_root, 'workflow.rb.erb')
        template_content = File.read(template_path)
        erb = ERB.new(template_content, trim_mode: '-')

        Ai.config.endpoint = options[:endpoint] if options[:endpoint]

        workflow = fetch_workflow(workflow_name)

        input_schema = workflow.fetch('input_schema')
        output_schema = workflow.fetch('output_schema')

        input_struct = SchemaToStructString.convert(input_schema, class_name: 'Input')
        output_struct = SchemaToStructString.convert(output_schema, class_name: 'Output')

        # to correctly place within module hierarchy
        @input_struct = indent(input_struct, 6)
        @output_struct = indent(output_struct, 6)
        @workflow_name = workflow_name

        erb.result(binding)
      end

      def fetch_workflow_names
        validate_endpoint!
        Ai.config.endpoint = options[:endpoint]
        url = URI.join(options[:endpoint] || ENV['MASTRA_LOCATION'], 'api/workflows')
        response = Net::HTTP.get(url)
        JSON.parse(response).keys
      end

      def fetch_workflow(workflow_name)
        validate_endpoint!
        Ai.config.endpoint = options[:endpoint]

        client =
          Ai.config.client ||
            Ai::Clients::Mastra.new(options[:endpoint] || ENV.fetch('MASTRA_LOCATION'))
        client.get_workflow(workflow_name)
      end

      #####################
      # Validation helpers
      #####################

      def validate_workflow_name!(workflow_name)
        if workflow_name.nil? || workflow_name.strip.empty?
          raise ArgumentError, 'Workflow name cannot be empty'
        end

        unless workflow_name.match?(/\A[a-zA-Z_][a-zA-Z0-9_]*\z/)
          raise ArgumentError, "Workflow name must be a valid Ruby identifier: #{workflow_name}"
        end
      end

      def validate_endpoint!
        if options[:endpoint].to_s.empty? && ENV['MASTRA_LOCATION'].to_s.empty?
          raise ArgumentError,
                'Mastra API URL is required. Use --endpoint to specify it or set the MASTRA_LOCATION environment variable'
        end
      end

      def indent(str, n)
        str.split("\n").map { |line| (' ' * n) + line }.join("\n")
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
