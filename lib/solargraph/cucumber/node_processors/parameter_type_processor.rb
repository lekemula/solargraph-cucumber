# frozen_string_literal: true

module Solargraph
  module Cucumber
    module NodeProcessors
      # PROTOTYPE: records `ParameterType(name: 'color', regexp: /red|green/, ...)`.
      class ParameterTypeProcessor < Walker::BaseProcessor
        on_node_pattern_enter <<~PATTERN, :record
          (send nil? :ParameterType (hash <(pair (sym :name) (str $_)) (pair (sym :regexp) $_) ...>))
        PATTERN

        private

        # @param node [RuboCop::AST::SendNode]
        # @param name [String]
        # @param regexp [RuboCop::AST::Node]
        # @return [void]
        def record(node, name, regexp)
          regexps = literal_regexps(regexp)

          (walker.context[:parameter_types] ||= []) << ParameterTypeDefinition.new(
            name: name,
            regexps: regexps || [/.*?/],
            approximate: regexps.nil?,
            location: Solargraph::Location.from_node(node)
          )
        end

        # @param node [RuboCop::AST::Node]
        # @return [Array<Regexp, String>, nil] nil when any part is not a literal
        def literal_regexps(node)
          nodes = node.array_type? ? node.values : [node]
          regexps = nodes.map do |n|
            if n.str_type? then n.value
            elsif n.regexp_type? && !n.interpolation? then n.to_regexp
            end
          end
          regexps unless regexps.include?(nil)
        end
      end
    end
  end
end
