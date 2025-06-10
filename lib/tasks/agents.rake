require 'rake'
require_relative '../ai'
require_relative '../ai/utils/agent_generator'
require_relative '../ai/utils/mastra_agents'

namespace :agents do
  desc 'Generate agent files for all agents from Mastra (use FORCE=true to overwrite existing files)'
  task :generate_all do
    puts 'Fetching agents from Mastra...'
    force = ENV['FORCE'] == 'true'
    puts '🔄 Force mode enabled - will overwrite existing files' if force

    begin
      agent_names = Ai::Utils::MastraAgents.all
      puts "Found #{agent_names.length} agents: #{agent_names.join(', ')}"

      if agent_names.empty?
        puts 'No agents found. Exiting.'
        exit 0
      end

      generated_count = 0
      skipped_count = 0
      errors = []

      agent_names.each do |agent_name|
        puts "Generating agent: #{agent_name}"
        Ai::Utils::AgentGenerator.generate(agent_name, force: force)
        generated_count += 1
      rescue ArgumentError => e
        if e.message.include?('Agent file already exists') && !force
          puts "  ⚠️  Skipped #{agent_name} (file already exists)"
          skipped_count += 1
        else
          puts "  ❌ Error generating #{agent_name}: #{e.message}"
          errors << "#{agent_name}: #{e.message}"
        end
      rescue StandardError => e
        puts "  ❌ Unexpected error generating #{agent_name}: #{e.message}"
        errors << "#{agent_name}: #{e.message}"
      end

      # Regenerate agents.rb file with all autoloads
      puts 'Regenerating agents.rb file...'
      regenerate_agents_file(agent_names)

      puts "\n=== Summary ==="
      puts "✅ Generated: #{generated_count} agents"
      puts "⚠️  Skipped: #{skipped_count} agents (already existed)" unless force

      if errors.any?
        puts "❌ Errors: #{errors.length}"
        puts "\nErrors:"
        errors.each { |error| puts "  - #{error}" }
        exit 1
      else
        puts '🎉 All agents processed successfully!'
        puts '📝 Updated agents.rb with autoload statements'
      end
    rescue StandardError => e
      puts "❌ Failed to fetch agents from Mastra: #{e.message}"
      puts 'Make sure the Mastra service is running and accessible.'
      exit 1
    end
  end

  desc 'Generate a specific agent file (use FORCE=true to overwrite existing files)'
  task :generate, [:agent_name] do |_task, args|
    agent_name = args[:agent_name]
    force = ENV['FORCE'] == 'true'

    if agent_name.nil? || agent_name.strip.empty?
      puts 'Usage: rake agents:generate[agent_name]'
      puts 'Example: rake agents:generate[my_custom_agent]'
      puts 'Use FORCE=true to overwrite existing files: FORCE=true rake agents:generate[my_custom_agent]'
      exit 1
    end

    puts '🔄 Force mode enabled - will overwrite existing files' if force

    begin
      puts "Generating agent: #{agent_name}"
      Ai::Utils::AgentGenerator.generate(agent_name, force: force)

      # Regenerate agents.rb file with all available agents
      puts 'Regenerating agents.rb file...'
      all_agent_names = Ai::Utils::MastraAgents.all
      regenerate_agents_file(all_agent_names)

      puts "✅ Successfully generated agent: #{agent_name}"
      puts '📝 Updated agents.rb with autoload statements'
    rescue StandardError => e
      puts "❌ Error generating agent #{agent_name}: #{e.message}"
      exit 1
    end
  end

  desc 'List all available agents from Mastra'
  task :list do
    puts 'Fetching agents from Mastra...'
    agent_names = Ai::Utils::MastraAgents.all

    if agent_names.empty?
      puts 'No agents found.'
    else
      puts "Available agents (#{agent_names.length}):"
      agent_names.each_with_index { |name, index| puts "  #{index + 1}. #{name}" }
    end
  rescue StandardError => e
    puts "❌ Failed to fetch agents from Mastra: #{e.message}"
    puts 'Make sure the Mastra service is running and accessible.'
    exit 1
  end

  desc 'Regenerate agents.rb file with autoload statements for all available agents'
  task :regenerate_autoloads do
    puts 'Fetching agents from Mastra...'
    agent_names = Ai::Utils::MastraAgents.all

    puts "Regenerating agents.rb file with #{agent_names.length} agents..."
    regenerate_agents_file(agent_names)

    puts '✅ Successfully regenerated agents.rb file'
  rescue StandardError => e
    puts "❌ Error regenerating agents.rb: #{e.message}"
    exit 1
  end

  private

  def regenerate_agents_file(agent_names)
    agents_file_path = File.join(__dir__, '..', 'ai', 'agents.rb')

    content = "# typed: strict\n\n"
    content += "module Ai\n"
    content += "  module Agents\n"

    agent_names.sort.each do |agent_name|
      class_name = agent_name.classify
      file_name = "ai/agents/#{agent_name.underscore}"
      content += "    autoload :#{class_name}, '#{file_name}'\n"
    end

    content += "  end\n"
    content += "end\n"

    File.write(agents_file_path, content)
  end
end
