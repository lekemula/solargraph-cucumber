# rubocop:disable Naming/FileName
# frozen_string_literal: true

require 'solargraph'
require 'rubocop-ast'

require_relative 'solargraph/cucumber/version'
require_relative 'solargraph/cucumber/convention'

Solargraph::Convention.register Solargraph::Cucumber::Convention
# rubocop:enable Naming/FileName
