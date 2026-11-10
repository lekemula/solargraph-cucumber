# frozen_string_literal: true

RSpec.describe Solargraph::Cucumber::Walker do
  def parse(code)
    RuboCop::AST::ProcessedSource.new(code, RUBY_VERSION.to_f).ast
  end

  around do |example|
    original_processors = described_class.processor_classes.dup
    example.run
    described_class.processor_classes.replace(original_processors)
  end

  describe '#walk!' do
    it 'dispatches enter and leave events depth-first to registered processors' do
      events = []
      Class.new(described_class::BaseProcessor) do
        on_node_type(:block) { |n| events << [:enter, n.method_name] }
        on_node_type_leave(:block) { |n| events << [:leave, n.method_name] }
      end

      described_class.new(parse("Given('a') { When('b') {} }")).walk!

      expect(events).to eq([%i[enter Given], %i[enter When], %i[leave When], %i[leave Given]])
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
