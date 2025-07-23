# AI

A Ruby gem for integrating AI agents from Mastra into your Rails application. This gem provides a Rails generator to create and manage AI agents seamlessly within your Ruby applications.

## Table of Contents

- [Overview](#overview)
- [Step-by-Step Guide](#step-by-step-guide)
  - [1. Create an Agent in Mastra](#1-create-an-agent-in-mastra)
  - [2. Generate the Agent Client](#2-generate-the-agent-client)
  - [3. Use the Agent in Your Rails Application](#3-use-the-agent-in-your-rails-application)
- [Generator Commands](#generator-commands)

## Overview

This gem provides a bridge between Mastra AI agents and your Rails application. It automatically generates client code for your agents and provides a consistent interface for calling them from your services.

## Step-by-Step Guide

### 1. Create an Agent in Mastra

Before you can use an agent in your Ruby application, you need to create it in Mastra first:

1. Create a new agent with your desired configuration
1. Note the agent name (this will be used in the next step)
1. Ensure the Mastra service is running and accessible

### 2. Generate the Agent Client

Once your agent is created in Mastra, generate the corresponding Ruby agent using the Rails generator:

```bash
# Generate all agents from Mastra
bin/rails generate ai:agent --all
```

This command will:

- Fetch the agent configuration from Mastra
- Generate the corresponding Ruby client file in `app/generated/ai/agents/`

### 3. Use the Agent in Your Rails Application

After generating the agent client, you can use it in your Rails application services:

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

  sig { params(input: String).returns(Output) }
  def self.call(input)
    # Your service logic here
    messages = [Ai.user_message(input)]
    
    # Initialize the agent (this would typically be done once and reused)
    agent = Ai::Agent.new(agent_name: 'my_custom_agent', client: Ai::Client.new)
    
    # Generate structured output
    result = agent.generate_object(
      messages: messages,
      output_class: Output
    )
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
result = MyAgentService.call("What is the weather like today?")

puts result.result      # => Agent's response
puts result.confidence  # => Confidence score
puts result.metadata    # => Additional metadata
```

#### Advanced Usage

The `generate_object` method supports additional options for fine-tuning:

```ruby
agent = Ai::Agent.new(agent_name: 'my_agent', client: Ai::Client.new)

result = agent.generate_object(
  messages: messages,
  output_class: Output,
  runtime_context: { user_id: 123, session: 'abc' },  # Optional context
  max_retries: 3,                                     # Retry attempts (default: 2)
  max_steps: 10                                       # Max processing steps (default: 5)
)

# Access the structured output
output = result.object
puts output.result
```

For simple text generation without structured output:

```ruby
agent = Ai::Agent.new(agent_name: 'my_agent', client: Ai::Client.new)

result = agent.generate_text(
  messages: messages,
  runtime_context: {},  # Optional context
  max_retries: 2,       # Retry attempts (default: 2)
  max_steps: 5          # Max processing steps (default: 5)
)

puts result.text  # Generated text response
```

#### Telemetry Configuration

The gem supports OpenTelemetry integration for monitoring and observability. You can configure telemetry settings to control what data is recorded and add metadata for better tracing:

**Telemetry Options:**
- `is_enabled`: Enable/disable telemetry (default: false)
- `record_inputs`: Record input messages (default: true, disable for sensitive data)
- `record_outputs`: Record output responses (default: true, disable for sensitive data)
- `function_id`: Identifier for grouping telemetry data by function
- `metadata`: Additional metadata for OpenTelemetry traces (agent identification, service info, etc.)


```ruby
# Create telemetry settings
telemetry_settings = Ai::TelemetrySettings.new(
  is_enabled: true,
  record_inputs: false,      # Disable for sensitive data
  record_outputs: true,      # Enable for monitoring
  function_id: 'user-chat-session',
  metadata: {
    'agent.name' => 'customer-support',
    'service.name' => 'mastra',
    'service.namespace' => 'customer-service',
    'cx.application.name' => 'ai-tracing',
    'cx.subsystem.name' => 'mastra-agents'
  }
)

# Use with text generation
result = agent.generate_text(
  messages: messages,
  telemetry: telemetry_settings
)

# Use with structured output
result = agent.generate_object(
  messages: messages,
  output_class: Output,
  telemetry: telemetry_settings
)
```


## Generating your agents

### `rails generate ai:agent AGENT_NAME [options]`

Generates a Ruby client for a specific agent or all agents from Mastra.

#### Basic Examples

```bash
# Generate a specific agent
bin/rails generate ai:agent my_agent --endpoint http://localhost:4111

# Generate all agents from Mastra
bin/rails generate ai:agent --all --endpoint http://localhost:4111
```

#### Options

- `--endpoint URL` - Mastra API endpoint URL (default: `MASTRA_LOCATION` environment variable)
- `--all` - Generate all agents from Mastra instead of a specific one
- `--force` - Override existing files
- `--output PATH` - Output directory for agent files (default: `app/ai/agents`)

#### Advanced Examples

```bash
# Generate with custom output directory
bin/rails generate ai:agent my_agent --endpoint http://localhost:4111 --output lib/custom/agents

# Force overwrite existing files
bin/rails generate ai:agent my_agent --endpoint http://localhost:4111 --force

# Generate all agents with custom settings
bin/rails generate ai:agent --all --endpoint http://localhost:4111 --output app/ai/agents --force
```
