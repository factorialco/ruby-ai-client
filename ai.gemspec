# frozen_string_literal: true

require_relative 'lib/ai/version'

Gem::Specification.new do |spec|
  spec.name = 'ai'
  spec.version = Ai::VERSION
  spec.authors = ['Oriol Gual']
  spec.email = ['oriol.gual@factorial.co']

  spec.summary = 'A Ruby gem for interacting with Mastra agents'
  spec.description = 'A Ruby gem for interacting with Mastra agents'
  spec.homepage = 'https://github.com/factorialco/factorial-ai'

  gemspec = File.basename(__FILE__)
  spec.files =
    IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
      ls
        .readlines("\x0", chomp: true)
        .reject do |f|
          (f == gemspec) ||
            f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
        end
    end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 3.0'
  spec.add_dependency 'actionpack', '>= 7.1.3'
  spec.add_dependency 'activesupport', '>= 7.1.3'
  spec.add_dependency 'json_schemer', '~> 2.4.0'
  spec.add_dependency 'railties', '>= 7.1.3'
  spec.add_dependency 'sorbet-coerce', '~> 0.7'
  spec.add_dependency 'sorbet-static-and-runtime', '0.6.12449'
end
