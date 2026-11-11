# frozen_string_literal: true

require 'gherkin/dialect'
require 'cucumber/cucumber_expressions/parameter_type_registry'
require 'cucumber/cucumber_expressions/parameter_type'
require 'cucumber/cucumber_expressions/expression_factory'
require 'cucumber/cucumber_expressions/errors'

module Solargraph
  module Cucumber
    # Same derivation as cucumber-ruby's `Glue::RegistryAndMore` + `Gherkin::I18n`.
    # @return [Set<Symbol>]
    keywords = Gherkin::DIALECTS.keys.flat_map do |code|
      dialect = Gherkin::Dialect.for(code)
      dialect.given_keywords + dialect.when_keywords + dialect.then_keywords +
        dialect.and_keywords + dialect.but_keywords
    end
    STEP_KEYWORDS = (keywords.uniq - ['* ']).to_set { |kw| kw.gsub(/[\s',!]/, '').to_sym }

    # @!attribute keyword [Symbol] the DSL method it was defined with; plays no part in matching
    # @!attribute expression [String, Regexp] String = Cucumber Expression, Regexp = regular expression
    # @!attribute approximate [Boolean] built from an interpolated literal
    # @!attribute location [Solargraph::Location]
    StepDefinition = Struct.new(:keyword, :expression, :approximate, :location, keyword_init: true)

    # @!attribute name [String]
    # @!attribute regexps [Array<Regexp, String>]
    # @!attribute approximate [Boolean] regexp was not a literal, so a placeholder stands in
    # @!attribute location [Solargraph::Location]
    ParameterTypeDefinition = Struct.new(:name, :regexps, :approximate, :location, keyword_init: true)

    # Turns the first argument of a Step Definition into a Step Expression.
    module StepExpression
      module_function

      # @param node [RuboCop::AST::Node] a str, dstr or regexp node
      # @return [Array(String, Boolean), Array(Regexp, Boolean)] expression and whether it is approximate
      def from_node(node)
        case node.type
        when :str then [node.value, false]
        # Each `#{}` becomes the anonymous `{}` Parameter Type, so the literal parts keep Cucumber semantics.
        when :dstr then [node.children.map { |part| part.str_type? ? part.value : '{}' }.join, true]
        when :regexp
          return [node.to_regexp, false] unless node.interpolation?

          source = node.children.map do |part|
            if part.str_type?
              part.value
            else
              (part.regopt_type? ? '' : '.*?')
            end
          end.join
          [Regexp.new(source, node.regopt.children.include?(:i) ? Regexp::IGNORECASE : nil), true]
        end
      end
    end

    # Walks step files with the Step Definition and Parameter Type processors only.
    class StepDefinitionWalker < Walker; end

    # Compiles Step Definitions found under `<root>/features/**/*.rb` and matches Step text against them.
    class StepIndex
      CE = ::Cucumber::CucumberExpressions
      NOOP = ->(*args) { args }

      # @!attribute step_definition [StepDefinition]
      # @!attribute matcher [CE::CucumberExpression, CE::RegularExpression]
      Compiled = Struct.new(:step_definition, :matcher, :approximate)

      # @return [Array<Array(StepDefinition, Exception)>] Step Definitions that failed to compile
      attr_reader :errors

      # @param root [String] workspace root
      def initialize(root)
        @root = root
        @files = {} # path => [mtime, step_definitions, parameter_types]
        @compiled = nil
        @errors = []
      end

      # @param step_text [String] Step text without the keyword
      # @return [Array<StepDefinition>] exact matches first, then approximate ones
      def matches(step_text)
        compiled.select { |c| safe_match?(c, step_text) }
                .sort_by { |c| c.approximate ? 1 : 0 }
                .map(&:step_definition)
      end

      # Approximate Matches only count when no text matches exactly.
      # @param step_texts [Array<String>] one Step's texts, e.g. an Outline Step expanded per Examples row
      # @return [Array<StepDefinition>] the union over all texts, in index order
      def best_matches(*step_texts)
        hits = compiled.select { |c| step_texts.any? { |text| safe_match?(c, text) } }
        exact, approximate = hits.partition { |c| !c.approximate }
        (exact.empty? ? approximate : exact).map(&:step_definition)
      end

      # @return [Array<StepDefinition>]
      def step_definitions
        refresh
        @files.values.flat_map { |entry| entry[1] }
      end

      # @return [Array<ParameterTypeDefinition>]
      def parameter_types
        refresh
        @files.values.flat_map { |entry| entry[2] }
      end

      private

      # @return [Array<Compiled>]
      def compiled
        @compiled = nil if refresh
        @compiled ||= compile
      end

      # Re-walks changed files; drops deleted ones.
      # @return [Boolean] whether anything changed
      def refresh
        paths = Dir.glob(File.join(@root, 'features', '**', '*.rb'))
        changed = (@files.keys - paths).each { |gone| @files.delete(gone) }.any?
        paths.each do |path|
          mtime = File.mtime(path)
          next if @files[path]&.first == mtime

          @files[path] = [mtime, *walk(path)]
          changed = true
        end
        changed
      end

      # @param path [String]
      # @return [Array(Array<StepDefinition>, Array<ParameterTypeDefinition>)]
      def walk(path)
        walker = StepDefinitionWalker.new(Solargraph::Parser.parse(File.read(path), path))
        walker.walk!
        [walker.context.fetch(:step_definitions, []), walker.context.fetch(:parameter_types, [])]
      rescue StandardError => e
        Solargraph.logger.warn("[cucumber] cannot index #{path}: #{e.message}")
        [[], []]
      end

      # @return [Array<Compiled>]
      def compile
        @errors = []
        registry = CE::ParameterTypeRegistry.new
        parameter_types.each do |pt|
          registry.define_parameter_type(CE::ParameterType.new(pt.name, pt.regexps, Object, NOOP, true, false))
        rescue StandardError => e
          @errors << [pt, e]
        end
        factory = CE::ExpressionFactory.new(registry)

        step_definitions.filter_map do |sd|
          approximate = sd.approximate
          begin
            Compiled.new(sd, factory.create_expression(sd.expression), approximate)
          rescue CE::UndefinedParameterTypeError => e
            # Defined in a gem or built dynamically: let `{name}` match anything.
            registry.define_parameter_type(
              CE::ParameterType.new(e.undefined_parameter_type_name, /.*?/, Object, NOOP, false, false)
            )
            approximate = true
            retry
          rescue StandardError => e
            @errors << [sd, e]
            nil
          end
        end
      end

      # @param compiled [Compiled]
      # @param text [String]
      # @return [Boolean]
      def safe_match?(compiled, text)
        !compiled.matcher.match(text).nil?
      rescue CE::AmbiguousParameterTypeError
        true
      end
    end
  end
end

require_relative 'node_processors/step_definition_processor'
require_relative 'node_processors/parameter_type_processor'
