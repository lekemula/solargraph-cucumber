# frozen_string_literal: true

require 'rubocop'
require 'rubocop/rspec/support'
require_relative '../../../../rubocop/cop/solargraph_cucumber/struct_param_tags'

RSpec.describe RuboCop::Cop::SolargraphCucumber::StructParamTags, :config do
  include RuboCop::RSpec::ExpectOffense

  it 'flags @!attribute tags above a Struct.new assignment and rewrites them as @param' do
    expect_offense(<<~RUBY)
      # A step.
      # @!attribute text [String] the Step text
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Document Struct/Data members with `@param`, not `@!attribute`.
      # @!attribute location [Solargraph::Location]
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Document Struct/Data members with `@param`, not `@!attribute`.
      Step = Struct.new(:text, :location)
    RUBY

    expect_correction(<<~RUBY)
      # A step.
      # @param text [String] the Step text
      # @param location [Solargraph::Location]
      Step = Struct.new(:text, :location)
    RUBY
  end

  it 'flags @!attribute tags above a Data.define assignment' do
    expect_offense(<<~RUBY)
      # @!attribute name [String]
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^ Document Struct/Data members with `@param`, not `@!attribute`.
      Point = ::Data.define(:name)
    RUBY

    expect_correction(<<~RUBY)
      # @param name [String]
      Point = ::Data.define(:name)
    RUBY
  end

  it 'flags a Struct.new assignment with a block' do
    expect_offense(<<~RUBY)
      # @!attribute name [String]
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^ Document Struct/Data members with `@param`, not `@!attribute`.
      Point = Struct.new(:name) do
        def to_s
          name
        end
      end
    RUBY
  end

  it 'flags an @!attribute with a read/write mode but leaves it for a human to rewrite' do
    expect_offense(<<~RUBY)
      # @!attribute [r] name
      ^^^^^^^^^^^^^^^^^^^^^^ Document Struct/Data members with `@param`, not `@!attribute`.
      Point = Struct.new(:name)
    RUBY

    expect_no_corrections
  end

  it 'accepts @param tags' do
    expect_no_offenses(<<~RUBY)
      # @param name [String]
      Point = Struct.new(:name)
    RUBY
  end

  it 'accepts @!attribute tags that are not directly above a Struct or Data assignment' do
    expect_no_offenses(<<~RUBY)
      # @!attribute name [String]
      NAME = 'x'

      # @!attribute name [String]

      Point = Struct.new(:name)

      class Point
        # @!attribute [r] name
        #   @return [String]
        attr_reader :name
      end
    RUBY
  end
end
