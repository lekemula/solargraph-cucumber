# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in solargraph-cucumber.gemspec
gemspec

# Development Dependencies
gem 'bundler'             # Dependency management
gem 'cucumber'            # Its DSL docs, for step file hover specs
gem 'debug'               # Debugging
gem 'rake'                # Build
gem 'rspec'               # Testing
gem 'rubocop'             # Linting
gem 'rubocop-yard'        # YARD documentation linting
gem 'simplecov'           # Code coverage
gem 'simplecov-cobertura' # Code coverage

# Solargraph with the unreleased core changes this plugin needs (castwide/solargraph#1489): a local checkout of
# the `cucumber` branch when there is one (or SOLARGRAPH_PATH), else that branch on GitHub
solargraph_path = ENV.fetch('SOLARGRAPH_PATH') do
  File.expand_path('~/Projects/open_source/solargraph__worktrees/cucumber')
end
if Dir.exist?(solargraph_path)
  gem 'solargraph', path: solargraph_path
else
  gem 'solargraph', github: 'lekemula/solargraph', branch: 'cucumber'
end
