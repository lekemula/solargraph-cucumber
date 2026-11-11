# frozen_string_literal: true

require_relative '../../script/lsp_probe'

# Runs the real `solargraph stdio` server over the fixture project, which loads the plugin through its own
# .solargraph.yml as a user's project does.
RSpec.describe 'solargraph stdio with the plugin', :lsp do
  root = File.expand_path('../fixtures/cucumber_project', __dir__)
  features = %w[features/cucumber_expressions.feature features/german.feature features/ambiguous.feature]

  # [feature, 1-based Step line] => expected "file:line" targets
  checklist = {
    ['features/cucumber_expressions.feature', 4] => ['basket_steps.rb:3'],
    ['features/cucumber_expressions.feature', 16] => ['regexp_steps.rb:3'],
    ['features/cucumber_expressions.feature', 28] => ['basket_steps.rb:7'],
    ['features/german.feature', 5] => ['german_steps.rb:3'],
    ['features/german.feature', 7] => ['basket_steps.rb:11'],
    ['features/ambiguous.feature', 5] => ['ambiguous_steps.rb:4', 'ambiguous_steps.rb:7']
  }

  before(:all) do
    @probe = LspProbe.start(
      root,
      env: {
        'BUNDLE_GEMFILE' => File.expand_path('../../Gemfile', __dir__),
        'SOLARGRAPH_GLOBAL_CONFIG' => File.join(root, 'no-global-config.yml')
      }
    )
    features.each { |feature| @probe.open(feature) }
  end

  after(:all) { @probe&.stop }

  # @param feature [String]
  # @param line [Integer] 1-based
  # @return [Array<String>] "file:line" of each definition, 1-based
  def definitions_at(feature, line)
    step_line = File.readlines(File.join(@probe.root, feature))[line - 1]
    column = step_line.index(/\S/) + step_line.lstrip.index(' ') + 3
    @probe.definition(feature, line - 1, column).map do |location|
      "#{File.basename(location["uri"])}:#{location["range"]["start"]["line"] + 1}"
    end
  end

  checklist.each do |(feature, line), targets|
    it "jumps from #{File.basename(feature)}:#{line} to #{targets.join(" and ")}" do
      expect(definitions_at(feature, line)).to eq targets
    end
  end

  features.each do |feature|
    it "formats #{File.basename(feature)} without edits" do
      expect(@probe.formatting(feature)).to eq []
    end

    it "reports no diagnostics on #{File.basename(feature)}" do
      expect(@probe.diagnostics(feature)).to eq []
    end
  end

  it 'logs no plugin failure, exception or backtrace' do
    @probe.definition(features.first, 3, 10)
    expect(@probe.stderr).not_to match(/Failed to load plugin|Error|Exception|\.rb:\d+:in /)
  end
end
