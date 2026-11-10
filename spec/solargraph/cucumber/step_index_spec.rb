# frozen_string_literal: true

require 'solargraph/cucumber/step_index'
require 'tmpdir'

RSpec.describe Solargraph::Cucumber::StepIndex do
  subject(:index) { described_class.new(root) }

  let(:root) { Dir.mktmpdir }

  after { FileUtils.remove_entry(root) }

  def write(path, code)
    full = File.join(root, path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, code)
  end

  def lines_for(text)
    index.matches(text).map { |sd| sd.location.range.start.line + 1 }
  end

  it 'matches Cucumber Expressions, regexps and other dialects' do
    write 'features/step_definitions/steps.rb', <<~RUBY
      Given('I have {int} cucumber(s)') { }
      Then(/^I see (\\d+)$/) { }
      Angenommen('ich habe {int} Gurken') { }
    RUBY

    expect(lines_for('I have 3 cucumbers')).to eq([1])
    expect(lines_for('I see 4')).to eq([2])
    expect(lines_for('ich habe 5 Gurken')).to eq([3])
    expect(lines_for('nothing')).to eq([])
  end

  it 'uses project Parameter Types and approximates unknown ones' do
    write 'features/support/types.rb', "ParameterType(name: 'color', regexp: /red|blue/, transformer: ->(s) { s })\n"
    write 'features/step_definitions/steps.rb', <<~RUBY
      When('I paint it {color}') { }
      When('I pick {flavour}') { }
    RUBY

    expect(lines_for('I paint it red')).to eq([1])
    expect(lines_for('I paint it green')).to eq([])
    expect(lines_for('I pick anything')).to eq([2])
  end

  it 'approximates interpolation and orders approximate matches last' do
    write 'features/step_definitions/steps.rb', <<~'RUBY'
      Given("I visit the #{PAGE} page") { }
      Given(/^I visit the (\w+) page$/) { }
    RUBY

    expect(lines_for('I visit the home page')).to eq([2, 1])
    expect(index.step_definitions.first.approximate).to be(true)
  end

  it 'isolates a definition that fails to compile' do
    write 'features/step_definitions/steps.rb', <<~'RUBY'
      Given(/^named (?<n>\d+)$/) { }
      Given('fine') { }
    RUBY

    expect(lines_for('fine')).to eq([2])
    expect(index.errors.size).to eq(1)
  end

  it 'picks up changed files' do
    write 'features/step_definitions/steps.rb', "Given('old') { }\n"
    expect(lines_for('old')).to eq([1])

    write 'features/step_definitions/steps.rb', "\nGiven('new') { }\n"
    File.utime(Time.now + 5, Time.now + 5, File.join(root, 'features/step_definitions/steps.rb'))
    expect(lines_for('old')).to eq([])
    expect(lines_for('new')).to eq([2])
  end
end
