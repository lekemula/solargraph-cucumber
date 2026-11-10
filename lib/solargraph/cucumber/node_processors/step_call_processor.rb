# frozen_string_literal: true

module Solargraph
  module Cucumber
    module NodeProcessors
      # Records the keyword method calls a Shadow Source makes for its Steps, e.g. `Given"I have 3 cukes"`.
      class StepCallProcessor < Walker::BaseProcessor
        walked_by ShadowSourceWalker
        on_node_pattern_enter '(send nil? $_ $str)', :record

        private

        # @param node [RuboCop::AST::SendNode]
        # @param method_name [Symbol]
        # @param str [RuboCop::AST::StrNode]
        # @return [void]
        def record(node, method_name, str)
          return unless in_feature_namespace?(node)

          (walker.context[:steps] ||= []) << Step.new(
            method_name: method_name.to_s,
            text: raw_text(str),
            location: text_location(str)
          )
        end

        # @param node [RuboCop::AST::Node]
        # @return [Boolean]
        def in_feature_namespace?(node)
          node.each_ancestor(:module).any? { |mod| mod.identifier.short_name == ShadowSource::NAMESPACE.to_sym }
        end

        # The parsed value would differ from the Step text where the text has `\\` inside a `'…'` literal.
        # @param str [RuboCop::AST::StrNode]
        # @return [String]
        def raw_text(str)
          text_range(str).source
        end

        # @param str [RuboCop::AST::StrNode]
        # @return [Solargraph::Location]
        def text_location(str)
          range = text_range(str)
          Solargraph::Location.new(range.source_buffer.name, Solargraph::Range.from_expr(range))
        end

        # @param str [RuboCop::AST::StrNode]
        # @return [::Parser::Source::Range]
        def text_range(str)
          str.loc.begin.end.join(str.loc.end.begin)
        end
      end
    end
  end
end
