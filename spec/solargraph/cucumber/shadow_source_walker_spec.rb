# frozen_string_literal: true

RSpec.describe Solargraph::Cucumber::ShadowSourceWalker do
  def steps_of(feature)
    described_class.new(Solargraph::Source.load_string(feature, 'features/x.feature')).steps
  end

  it 'finds each Step with the keyword method it calls, its raw text and where the text sits' do
    steps = steps_of(<<~'GHERKIN')
      Feature: Baskets
        Scenario: x
          Given I have 3 cucumbers
          And the label says "Fresh" and is filed under C:\\baskets
          But a sign says "don't panic"
    GHERKIN

    expect(steps.map { |s| [s.method_name, s.text, s.location.range.start.line, s.location.range.start.column] })
      .to eq [
        ['Given', 'I have 3 cucumbers', 2, 10],
        ['And', 'the label says "Fresh" and is filed under C:\\\\baskets', 3, 8],
        ['But', 'a sign says "don\'t panic"', 4, 8]
      ]
    expect(steps.map { |s| s.location.filename }.uniq).to eq ['features/x.feature']
  end

  it 'names the method of a localized keyword' do
    steps = steps_of("# language: de\nFunktionalität: x\n  Szenario: y\n    Gegeben sei ich habe 5 Gurken\n")

    expect(steps.map { |s| [s.method_name, s.text] }).to eq [['Gegeben_sei', 'ich habe 5 Gurken']]
  end

  it 'ignores calls outside the CucumberFeature namespace' do
    source = Solargraph::Source.load_string("Given 'a'\nmodule CucumberFeature; Given 'b'; end\n", 'x.rb')

    expect(described_class.new(source).steps.map(&:text)).to eq ['b']
  end
end
