# frozen_string_literal: true

module Solargraph
  module Cucumber
    # Generic AST walker with a processor registry.
    # Each subclass has its own registry; processors join it with {BaseProcessor.walked_by}.
    # Subclasses add domain-specific setup around {#walk!}.
    class Walker
      class << self
        # @return [Array<Class>]
        def processor_classes
          @processor_classes ||= []
        end

        # @param klass [Class]
        # @return [void]
        def register_processor(klass)
          processor_classes << klass
        end
      end

      # @param source [RuboCop::AST::Node, ::Parser::AST::Node, Solargraph::Source, nil]
      def initialize(source = nil)
        @ast = to_rubocop_ast(source.is_a?(Solargraph::Source) ? source.node : source)
      end

      # @return [Hash]
      def context
        @context ||= {}
      end

      # Register a callback to be called after the walk completes.
      # @return [void]
      def on_after_walk(&block)
        (@after_walk_handlers ||= []) << block
      end

      # Walk the AST, dispatching enter/leave events to all registered processors.
      # @return [void]
      def walk!
        return unless @ast

        @processors = self.class.processor_classes.map { |klass| klass.new(self) }
        walk(@ast)
        (@after_walk_handlers ||= []).each(&:call)
      end

      private

      # Processors match with RuboCop node patterns and helpers, but Solargraph parses into plain Parser nodes.
      # @param node [::Parser::AST::Node, Object]
      # @return [RuboCop::AST::Node, Object]
      def to_rubocop_ast(node)
        return node if !node.is_a?(::Parser::AST::Node) || node.is_a?(::RuboCop::AST::Node)

        ::RuboCop::AST::Builder.new.n(node.type, node.children.map { |child| to_rubocop_ast(child) }, node.loc)
      end

      # @param node [RuboCop::AST::Node]
      # @return [void]
      def walk(node)
        return unless node.is_a?(::RuboCop::AST::Node)

        @processors&.each { |p| p.dispatch_enter(node) }
        node.each_child_node { |child| walk(child) }
        @processors&.each { |p| p.dispatch_leave(node) }
      end
    end
  end
end

require_relative 'walker/base_processor'
