# frozen_string_literal: true

module Solargraph
  module Cucumber
    module NodeProcessors
      # PROTOTYPE: records `Given('...') { }` and friends, in any Gherkin dialect.
      class StepDefinitionProcessor < Walker::BaseProcessor
        walked_by StepDefinitionWalker
        on_node_pattern_enter '(block (send nil? #step_keyword? {str dstr regexp} ...) ...)', :record

        # @param keyword [Symbol]
        # @return [Boolean]
        def step_keyword?(keyword)
          STEP_KEYWORDS.include?(keyword)
        end

        private

        # @param node [RuboCop::AST::BlockNode]
        # @return [void]
        def record(node)
          send_node = node.send_node
          expression, approximate = StepExpression.from_node(send_node.first_argument)

          (walker.context[:step_definitions] ||= []) << StepDefinition.new(
            keyword: send_node.method_name,
            expression: expression,
            approximate: approximate,
            location: Solargraph::Location.from_node(send_node)
          )
        end
      end
    end
  end
end
