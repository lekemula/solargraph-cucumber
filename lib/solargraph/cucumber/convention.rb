# frozen_string_literal: true

require 'gherkin'
require_relative 'shadow_source_walker'
require_relative 'step_index'
require_relative 'step_keyword'

module Solargraph
  module Cucumber
    # Links Cucumber steps to their step definitions.
    #
    # A `.feature` file becomes its Shadow Source, where each Step calls a keyword method of `CucumberFeature` with its
    # text. Each Step Definition a Step matches becomes a FactoryParameter pin on that call, so Solargraph's
    # go-to-definition on the Step text jumps to the Step Definition.
    class Convention < Solargraph::Convention::Base
      PARAM_NAME = 'text'

      # @param filename [String]
      # @param code [String]
      # @return [String, nil] the Shadow Source of a `.feature` file
      def transform_source(filename, code)
        ShadowSource.new(code, namespace: true).code if filename.end_with?('.feature')
      end

      # @param _yard_map [YardMap]
      # @return [Environ]
      def global(_yard_map)
        EMPTY_ENVIRON
      end

      # @param source_map [SourceMap]
      # @return [Environ]
      def local(source_map)
        filename = source_map.filename
        return EMPTY_ENVIRON unless filename&.end_with?('.feature') && source_map.source.transformed?

        feature = source_map.source.original_code
        Environ.new(pins: [namespace_pin, *keyword_method_pins(feature), *factory_parameters(source_map, feature)])
      end

      private

      # @param filename [String]
      # @return [StepIndex, nil] nil when the file is not under a `features` directory
      def step_index(filename)
        features = Pathname.new(File.expand_path(filename)).ascend.find { |dir| dir.basename.to_s == 'features' }
        return unless features

        root = features.dirname.to_s
        (@step_indexes ||= {})[root] ||= StepIndex.new(root)
      end

      # @return [Pin::Namespace]
      def namespace_pin
        @namespace_pin ||= Pin::Namespace.new(name: ShadowSource::NAMESPACE, type: :module, closure: Pin::ROOT_PIN)
      end

      # @param feature [String]
      # @return [Array<Pin::Method>]
      def keyword_method_pins(feature)
        language = ShadowSource.language(feature)
        language = 'en' unless Gherkin::DIALECTS.key?(language)
        ShadowSource.step_keywords(Gherkin::Dialect.for(language)).map do |keyword|
          name = ShadowSource.method_name(keyword)
          Pin::Method.new(name: name, closure: namespace_pin, scope: :class, visibility: :public,
                          comments: StepKeyword::DOCS[keyword.strip]).tap do |pin|
            pin.parameters.push Pin::Parameter.new(name: PARAM_NAME, closure: pin)
          end
        end
      end

      # Chain::Parameter looks a Step's pins up by method and text, so a Step written twice needs its pins once.
      # @param source_map [SourceMap]
      # @param feature [String]
      # @return [Array<Pin::FactoryParameter>]
      def factory_parameters(source_map, feature)
        index = step_index(source_map.filename)
        return [] unless index

        texts = expanded_texts(source_map.filename, feature)
        pins = ShadowSourceWalker.new(source_map.source).steps.flat_map do |step|
          step_definitions = index.best_matches(*texts.fetch(step.location.range.start.line + 1, [step.text]))
          step_definitions.map { |step_definition| factory_parameter(step, step_definition) }
        end
        pins.uniq { |pin| [pin.method_name, pin.value, pin.location] }
      end

      # Outline Steps expand once per Examples row; other Steps keep their text.
      # @param filename [String]
      # @param feature [String]
      # @return [Hash{Integer => Array<String>}] the Pickle texts of each Step, by 1-based line
      def expanded_texts(filename, feature)
        envelopes = Gherkin.from_source(filename, feature, include_source: false, include_gherkin_document: true,
                                                           include_pickles: true).to_a
        document = envelopes.find(&:gherkin_document)&.gherkin_document
        return {} unless document&.feature

        step_lines = {}
        each_step(document.feature.children) { |step| step_lines[step.id] = step.location.line }
        texts = Hash.new { |hash, line| hash[line] = [] }
        envelopes.filter_map(&:pickle).each do |pickle|
          pickle.steps.each do |pickle_step|
            texts[step_lines.fetch(pickle_step.ast_node_ids.first)] << pickle_step.text
          end
        end
        texts.transform_values(&:uniq)
      end

      # @param children [Array<Cucumber::Messages::FeatureChild, Cucumber::Messages::RuleChild>]
      # @yieldparam [Cucumber::Messages::Step]
      # @return [void]
      def each_step(children, &block)
        children.each do |child|
          each_step(child.rule.children, &block) if child.respond_to?(:rule) && child.rule
          (child.scenario || child.background)&.steps&.each(&block)
        end
      end

      # @param step [Step]
      # @param step_definition [StepDefinition]
      # @return [Pin::FactoryParameter]
      def factory_parameter(step, step_definition)
        Pin::FactoryParameter.new(
          method_name: step.method_name,
          method_namespace: ShadowSource::NAMESPACE,
          method_scope: :class,
          param_name: PARAM_NAME,
          decl: :arg,
          value: step.text,
          location: step_definition.location,
          return_type: nil
        )
      end
    end
  end
end
