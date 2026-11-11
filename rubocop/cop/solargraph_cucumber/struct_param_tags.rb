# frozen_string_literal: true

require 'rubocop'

module RuboCop
  module Cop
    module SolargraphCucumber
      # Solargraph types the members of a `Struct.new` or `Data.define` assignment from `@param` tags on the
      # assignment's comment and ignores `@!attribute` there, so document the members with `@param`.
      #
      # @example
      #   # bad
      #   # @!attribute text [String]
      #   Step = Struct.new(:text)
      #
      #   # good
      #   # @param text [String]
      #   Step = Struct.new(:text)
      class StructParamTags < Base
        extend AutoCorrector

        MSG = 'Document Struct/Data members with `@param`, not `@!attribute`.'
        ATTRIBUTE = /\A#\s*@!attribute\b/
        # `@!attribute name [Type] text`, which maps onto `@param` one to one
        SIMPLE_ATTRIBUTE = /\A(#\s*)@!attribute(\s+\w+\s+\[)/

        # @!method struct_assignment?(node)
        #   @param node [RuboCop::AST::Node]
        #   @return [Boolean]
        def_node_matcher :struct_assignment?, <<~PATTERN
          (casgn _ _ {
            (send (const {nil? cbase} :Struct) :new ...)
            (send (const {nil? cbase} :Data) :define ...)
            (block (send (const {nil? cbase} :Struct) :new ...) ...)
            (block (send (const {nil? cbase} :Data) :define ...) ...)
          })
        PATTERN

        # @param node [RuboCop::AST::Node]
        # @return [void]
        def on_casgn(node)
          return unless struct_assignment?(node)

          comments_above(node).each do |comment|
            next unless comment.text.match?(ATTRIBUTE)

            add_offense(comment) do |corrector|
              next unless comment.text.match?(SIMPLE_ATTRIBUTE)

              corrector.replace(comment, comment.text.sub(SIMPLE_ATTRIBUTE, '\1@param\2'))
            end
          end
        end

        private

        # The comment lines that end on the line right above the node, without a gap.
        #
        # @param node [RuboCop::AST::Node]
        # @return [Array<Parser::Source::Comment>]
        def comments_above(node)
          by_line = processed_source.comments.to_h { |comment| [comment.loc.line, comment] }
          line = node.first_line - 1
          block = []
          while (comment = by_line[line])
            block.unshift(comment)
            line -= 1
          end
          block
        end
      end
    end
  end
end
