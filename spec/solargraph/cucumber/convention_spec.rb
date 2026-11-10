# frozen_string_literal: true

RSpec.describe Solargraph::Cucumber::Convention do
  it 'is registered as a Solargraph convention' do
    conventions = Solargraph::Convention.class_variable_get(:@@conventions)

    expect(conventions).to include(an_instance_of(described_class))
  end

  describe '#transform_source' do
    it 'turns a .feature file into its Shadow Source' do
      code = described_class.new.transform_source('features/a.feature', "Feature: a\n  Scenario: b\n    Given c\n")

      expect(code).to eq "module CucumberFeature;\n# Scenario: b\n    Given\"c\"\nend"
    end

    it 'leaves other files alone' do
      expect(described_class.new.transform_source('features/a.md', 'Given c')).to be_nil
    end
  end

  describe '#local' do
    it 'returns an empty environ' do
      source_map = Solargraph::SourceMap.load_string('Given(/^a step$/) {}', 'features/step_definitions/steps.rb')

      expect(described_class.new.local(source_map)).to eq(Solargraph::Convention::Base::EMPTY_ENVIRON)
    end
  end

  describe '#global' do
    it 'returns an empty environ' do
      expect(described_class.new.global(nil)).to eq(Solargraph::Convention::Base::EMPTY_ENVIRON)
    end
  end
end
