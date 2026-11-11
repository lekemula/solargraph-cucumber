# frozen_string_literal: true

require_relative 'shadow_source_walker'
require_relative 'step_index'

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
        return EMPTY_ENVIRON unless filename&.end_with?('.feature')

        index = step_index(filename)
        steps = ShadowSourceWalker.new(source_map.source).steps
        parameters = index ? steps.flat_map { |step| factory_parameters(step, index.best_matches(step.text)) } : []
        Environ.new(pins: [namespace_pin, *keyword_method_pins(original_code(source_map.source))] + parameters)
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

      # Core keeps the text a convention transformed only privately. Switch to the public reader once the ticket
      # "How do we keep Ruby diagnostics and formatting off .feature files?" adds `Source#original_code`.
      # @param source [Source]
      # @return [String]
      def original_code(source)
        source.instance_variable_get(:@original_code) || source.code
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
        ShadowSource.keyword_methods(language).map do |name|
          Pin::Method.new(name: name, closure: namespace_pin, scope: :class, visibility: :public).tap do |pin|
            pin.parameters.push Pin::Parameter.new(name: PARAM_NAME, closure: pin)
          end
        end
      end

      # @param step [Step]
      # @param step_definitions [Array<StepDefinition>]
      # @return [Array<Pin::FactoryParameter>]
      def factory_parameters(step, step_definitions)
        step_definitions.map do |step_definition|
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
end
