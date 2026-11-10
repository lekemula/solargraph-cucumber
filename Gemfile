# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in solargraph-cucumber.gemspec
gemspec

# Development Dependencies
gem 'bundler'             # Dependency management
gem 'debug'               # Debugging
gem 'rake'                # Build
gem 'rspec'               # Testing
gem 'rubocop'             # Linting
gem 'rubocop-yard'        # YARD documentation linting
gem 'simplecov'           # Code coverage
gem 'simplecov-cobertura' # Code coverage

# The solargraph `cucumber` integration branch, which carries the core changes this plugin needs;
# override with SOLARGRAPH_PATH
gem 'solargraph',
    path: ENV.fetch('SOLARGRAPH_PATH', File.expand_path('~/Projects/open_source/solargraph__worktrees/cucumber'))
