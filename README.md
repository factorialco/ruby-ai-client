# AI

A Ruby gem for integrating AI agents from Mastra into the Factorial Backend. This gem provides tools to generate, manage, and use AI agents seamlessly within your Ruby applications.

## Table of Contents

- [Overview](#overview)
- [Step-by-Step Guide](#step-by-step-guide)
  - [1. Create an Agent in Mastra](#1-create-an-agent-in-mastra)
  - [2. Generate the Agent Client](#2-generate-the-agent-client)
  - [3. Use the Agent in Factorial Backend](#3-use-the-agent-in-factorial-backend)
- [Available Rake Tasks](#available-rake-tasks)

## Overview

This gem provides a bridge between Mastra AI agents and our Rails application. It automatically generates client code for your agents and provides a consistent interface for calling them from your services.

## Step-by-Step Guide

### 1. Create an Agent in Mastra

Before you can use an agent in your Ruby application, you need to create it in Mastra first:

1. Create a new agent with your desired configuration
1. Note the agent name (this will be used in the next step)
1. Ensure the Mastra service is running and accessible

### 2. Generate the Agent Client

Once your agent is created in Mastra, generate the corresponding Ruby client (at the `ruby-ai-agents` folder):

```bash
# Generate a specific agent
bundle exec rake agents:generate[my_custom_agent]

# Force overwrite existing files (if needed)
FORCE=true bundle exec rake agents:generate[my_custom_agent]
```

This command will:

- Fetch the agent configuration from Mastra
- Generate the corresponding Ruby client file
- Update the `agents.rb` file with autoload statements
- Make the agent available for use in your application

### 3. Use the Agent in Factorial Backend

After generating the agent client, you can use it in your Factorial Backend services:

#### Step 3.1: Define an Output Structure

Create a service that defines an output class using `T::Struct`:

```ruby
class MyAgentService
  extend T::Sig

  # Define the expected output structure
  class Output < T::Struct
    const :result, String
    const :confidence, Float
    const :metadata, T::Hash[String, T.untyped], default: {}
  end

  sig { params(input: String).returns(Outcome[Output]) }
  def self.call(input)
    # Your service logic here
    messages = [Ai.user_message(input)]
    Outcome.ok(Ai::Agents::MyCustomAgent[Output].generate_object(messages))
  rescue Ai::Error
    Outcome.error("Didn't work")
  end
end
```

#### Step 3.2: Create Appropriate Messages

Structure your messages according to your agent's expected format:

```ruby
messages = [
  Ai.system_message("You are a helpful assistant that..."),
  Ai.user_message("User's question or request")
]
```

#### Step 3.3: Call the Agent

```ruby
# Use the service in your application
result = MyAgentService.call("What is the weather like today?").unwrap!

puts result.result      # => Agent's response
puts result.confidence  # => Confidence score
puts result.metadata    # => Additional metadata
```

## Available Rake Tasks

### `agents:generate[agent_name]`

Generates a Ruby client for a specific agent.

```bash
# Basic usage
bundle exec rake agents:generate[my_agent]

# Force overwrite existing files
FORCE=true bundle exec rake agents:generate[my_agent]
```

**Options:**

- `FORCE=true` - Overwrites existing agent files

### `agents:generate_all`

Generates Ruby clients for all available agents from Mastra.

```bash
# Generate all agents
bundle exec rake agents:generate_all

# Force overwrite all existing files
FORCE=true bundle exec rake agents:generate_all
```

**Features:**

- Fetches all available agents from Mastra
- Generates clients for each agent
- Provides detailed summary of generated, skipped, and failed agents
- Updates the main `agents.rb` file with autoload statements

### `agents:list`

Lists all available agents from Mastra without generating any files.

```bash
bundle exec rake agents:list
```

**Output example:**

```
Available agents (3):
  1. my_custom_agent
  2. data_analyzer
  3. content_generator
```

### `agents:regenerate_autoloads`

Regenerates the `agents.rb` file with autoload statements for all available agents.

```bash
bundle exec rake agents:regenerate_autoloads
```

**Use cases:**

- After manually adding/removing agent files
- When autoload statements get out of sync
- As part of deployment or maintenance tasks
