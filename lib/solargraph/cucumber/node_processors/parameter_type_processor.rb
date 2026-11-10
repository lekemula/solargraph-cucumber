# frozen_string_literal: true

module Solargraph
  module Cucumber
    module NodeProcessors
      # PROTOTYPE: records `ParameterType(name: 'color', regexp: /red|green/, ...)`.
      class ParameterTypeProcessor < Walker::BaseProcessor
        on_node_pattern_enter '(send nil? :ParameterType (hash <(pair (sym :name) str) ...>))', :record

        # Handlers only receive the node, so captures need their own matchers.
        # @!method name_of(node)
        #   @return [String, nil]
        def_node_matcher :name_of, '(send _ _ (hash <(pair (sym :name) (str $_)) ...>))'
        # @!method regexp_of(node)
        #   @return [RuboCop::AST::Node, nil]
        def_node_matcher :regexp_of, '(send _ _ (hash <(pair (sym :regexp) $_) ...>))'

        private

        # @param node [RuboCop::AST::SendNode]
        # @return [void]
        def record(node)
          name = name_of(node)
          regexps = literal_regexps(regexp_of(node))

          (walker.context[:parameter_types] ||= []) << ParameterTypeDefinition.new(
            name: name,
            regexps: regexps || [/.*?/],
            approximate: regexps.nil?,
            location: Solargraph::Location.from_node(node)
          )
        end

        # @param node [RuboCop::AST::Node, nil]
        # @return [Array<Regexp, String>, nil] nil when any part is not a literal
        def literal_regexps(node)
          nodes = node&.array_type? ? node.values : [node]
          regexps = nodes.map do |n|
            if n&.str_type? then n.value
            elsif n&.regexp_type? && !n.interpolation? then n.to_regexp
            end
          end
          regexps unless regexps.include?(nil)
        end
      end
    end
  end
end
