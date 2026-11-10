# frozen_string_literal: true

RSpec.describe Solargraph::Cucumber::Walker do
  def parse(code)
    RuboCop::AST::ProcessedSource.new(code, RUBY_VERSION.to_f).ast
  end

  describe '#walk!' do
    it 'dispatches enter and leave events depth-first to its processors' do
      events = []
      walker_class = Class.new(described_class)
      Class.new(described_class::BaseProcessor) do
        walked_by walker_class
        on_node_type(:block) { |n| events << [:enter, n.method_name] }
        on_node_type_leave(:block) { |n| events << [:leave, n.method_name] }
      end

      walker_class.new(parse("Given('a') { When('b') {} }")).walk!

      expect(events).to eq([%i[enter Given], %i[enter When], %i[leave When], %i[leave Given]])
    end

    it 'runs only the processors bound to its own walker class' do
      events = []
      shadow_walker = Class.new(described_class)
      step_walker = Class.new(described_class)
      Class.new(described_class::BaseProcessor) do
        walked_by shadow_walker
        on_node_type(:block) { events << :shadow }
      end
      Class.new(described_class::BaseProcessor) do
        walked_by step_walker
        on_node_type(:block) { events << :step }
      end

      step_walker.new(parse("Given('a') {}")).walk!
      expect(events).to eq([:step])

      shadow_walker.new(parse("Given('a') {}")).walk!
      expect(events).to eq(%i[step shadow])
    end

    context 'with a source that is not a RuboCop AST' do
      let(:entered) { [] }
      let(:walker_class) do
        entered_ref = entered
        Class.new(described_class).tap do |walker_class|
          Class.new(described_class::BaseProcessor) do
            walked_by walker_class
            on_node_pattern_enter('(block (send nil? $_ ...) ...)') { |n, name| entered_ref << [n.class, name] }
          end
        end
      end

      it 'walks a Parser AST as RuboCop nodes' do
        walker_class.new(Solargraph::Parser.parse("Given('a') {}", 'steps.rb')).walk!

        expect(entered).to eq([[RuboCop::AST::BlockNode, :Given]])
      end

      it 'walks a Solargraph source as RuboCop nodes' do
        walker_class.new(Solargraph::Source.load_string("Given('a') {}", 'steps.rb')).walk!

        expect(entered).to eq([[RuboCop::AST::BlockNode, :Given]])
      end
    end

    it 'runs after-walk handlers once the walk completes' do
      walker = described_class.new(parse('Given {}'))
      called = false
      walker.on_after_walk { called = true }

      walker.walk!

      expect(called).to be(true)
    end

    it 'does nothing without an AST' do
      walker = described_class.new
      walker.on_after_walk { raise 'should not be called' }

      expect { walker.walk! }.not_to raise_error
    end
  end
end
