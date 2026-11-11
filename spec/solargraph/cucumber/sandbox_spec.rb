# frozen_string_literal: true

require 'tmpdir'

# The "Go-to-definition checklist" of the cucumber-sandbox README, run through a Solargraph::Library over a copy of the
# sandbox's features, with each feature opened as an editor would.
RSpec.describe 'go-to-definition in the cucumber-sandbox' do
  sandbox = ENV.fetch('CUCUMBER_SANDBOX', File.expand_path('~/Projects/open_source/cucumber-sandbox'))

  # feature => [[1-based Step line, expected "file:line" targets]]
  checklist = {
    'cucumber_expressions.feature' => [
      [4, ['basket_steps.rb:3']],
      [5, ['basket_steps.rb:11']],
      [9, ['basket_steps.rb:7']],
      [10, ['basket_steps.rb:7']],
      [15, ['basket_steps.rb:15']],
      [16, ['regexp_steps.rb:3']],
      [20, ['basket_steps.rb:15']],
      [22, ['basket_steps.rb:7']],
      [24, ['basket_steps.rb:19']],
      [27, ['basket_steps.rb:3']],
      [28, ['basket_steps.rb:7']],
      [29, ['basket_steps.rb:11']]
    ],
    'regular_expressions.feature' => [
      [6, ['regexp_steps.rb:3']],
      [10, ['regexp_steps.rb:7']]
    ],
    'parameter_types.feature' => [
      [5, ['color_steps.rb:3']],
      [6, ['color_steps.rb:7']]
    ],
    'step_arguments.feature' => [
      [5, ['text_steps.rb:3']],
      [13, ['text_steps.rb:7']],
      [16, ['text_steps.rb:11']],
      [24, ['text_steps.rb:15']]
    ],
    'german.feature' => [
      [5, ['german_steps.rb:3']],
      [6, ['german_steps.rb:7']],
      [7, ['basket_steps.rb:11']]
    ],
    'ambiguous.feature' => [
      [5, ['ambiguous_steps.rb:4', 'ambiguous_steps.rb:7']]
    ],
    'undefined.feature' => [
      [6, []]
    ]
  }

  before(:all) do
    skip "no cucumber-sandbox at #{sandbox}" unless File.directory?(File.join(sandbox, 'features'))

    @root = Dir.mktmpdir
    FileUtils.cp_r(File.join(sandbox, 'features'), @root)
    FileUtils.cp(File.join(sandbox, '.solargraph.yml'), @root)
    @library = Solargraph::Library.load(@root)
  end

  after(:all) { FileUtils.remove_entry(@root) if @root }

  # @return [Array<String>] "file:line" of each definition, 1-based like the README
  def definitions_at(feature, line)
    path = File.join(@root, 'features', feature)
    text = File.read(path)
    @library.attach Solargraph::Source.load_string(text, path)
    step_line = text.lines[line - 1]
    column = step_line.index(/\S/) + step_line.lstrip.index(' ') + 3
    @library.definitions_at(path, line - 1, column).map do |pin|
      "#{File.basename(pin.location.filename)}:#{pin.location.range.start.line + 1}"
    end
  end

  checklist.each do |feature, rows|
    rows.each do |line, targets|
      it "jumps from #{feature}:#{line} to #{targets.empty? ? "nothing" : targets.join(" and ")}" do
        expect(definitions_at(feature, line)).to eq targets
      end
    end
  end
end
