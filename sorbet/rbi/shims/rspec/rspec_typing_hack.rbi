# typed: strict

# This is a permissive shim to allow typechecking RSpec test files
# It establishes that the block received by RSpec DSL languages will be bound to `T.untyped`,
# making Sorbet not care about calling methods defined via `T.let` and the like.
# The intended result is that we can have typechecking for everything else in a spec file
# for example when calling normal code methods.
module RSpec
  class << self
    sig { params(args: T.untyped, example_group_block: T.proc.bind(T.untyped).void).void }
    def context(*args, &example_group_block)
    end

    sig { params(args: T.untyped, example_group_block: T.proc.bind(T.untyped).void).void }
    def describe(*args, &example_group_block)
    end

    sig { params(args: T.untyped, example_group_block: T.proc.bind(T.untyped).void).void }
    def example_group(*args, &example_group_block)
    end

    sig { params(args: T.untyped, example_group_block: T.proc.bind(T.untyped).void).void }
    def fcontext(*args, &example_group_block)
    end

    sig { params(args: T.untyped, example_group_block: T.proc.bind(T.untyped).void).void }
    def fdescribe(*args, &example_group_block)
    end

    sig { params(name: String, args: T.untyped, block: T.proc.bind(T.untyped).void).void }
    def shared_context(name, *args, &block)
    end

    sig do
      params(
        name: String,
        args: T.untyped,
        block: T.proc.params(args: T.untyped).bind(T.untyped).void
      ).void
    end
    def shared_examples(name, *args, &block)
    end

    sig { params(name: String, args: T.untyped, block: T.proc.bind(T.untyped).void).void }
    def shared_examples_for(name, *args, &block)
    end

    sig { params(args: T.untyped, example_group_block: T.proc.bind(T.untyped).void).void }
    def xcontext(*args, &example_group_block)
    end

    sig { params(args: T.untyped, example_group_block: T.proc.bind(T.untyped).void).void }
    def xdescribe(*args, &example_group_block)
    end

    sig do
      params(
        configuration_block: T.proc.bind(T.untyped).params(config: RSpec::Core::Configuration).void
      ).void
    end
    def configure(&configuration_block)
    end
  end

  class Core::Configuration
    sig { params(args: T.untyped).void }
    def verbose_retry=(*args)
    end
    sig { params(args: T.untyped).void }
    def display_try_failure_messages=(*args)
    end
    sig { params(args: T.untyped).void }
    def exceptions_to_retry=(*args)
    end
    sig { params(args: T.untyped).void }
    def default_retry_count=(*args)
    end
    sig { params(args: T.untyped).void }
    def use_transactional_fixtures=(*args)
    end
  end
end
