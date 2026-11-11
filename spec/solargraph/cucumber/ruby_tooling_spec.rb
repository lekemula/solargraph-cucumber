# frozen_string_literal: true

require 'tmpdir'

# Ruby diagnostics and formatting on the cucumber-sandbox's features, set up as the README advises: RuboCop excludes
# `.feature` files, and core skips the typecheck reporter and formatting on transformed sources.
RSpec.describe 'Ruby tooling in the cucumber-sandbox' do
  sandbox = ENV.fetch('CUCUMBER_SANDBOX', File.expand_path('~/Projects/open_source/cucumber-sandbox'))

  around do |example|
    skip "no cucumber-sandbox at #{sandbox}" unless File.directory?(File.join(sandbox, 'features'))

    Dir.mktmpdir do |dir|
      @root = File.realpath(dir)
      FileUtils.cp_r(File.join(sandbox, 'features'), @root)
      config = YAML.safe_load_file(File.join(sandbox, '.solargraph.yml'))
      File.write(File.join(@root, '.solargraph.yml'),
                 config.merge('reporters' => %w[rubocop typecheck:strong]).to_yaml)
      File.write(File.join(@root, '.rubocop.yml'), { 'AllCops' => { 'Exclude' => ['**/*.feature'] } }.to_yaml)
      # RuboCop's --force-exclusion reads the config of the working directory, like a server run in the workspace
      Dir.chdir(@root) { example.run }
    end
  end

  let(:features) { Dir[File.join(@root, 'features', '*.feature')] }

  # @return [Hash{String => Array<Hash>}] diagnostics per feature name
  def diagnose_features
    library = Solargraph::Library.load(@root)
    features.to_h do |path|
      library.attach Solargraph::Source.load_string(File.read(path), path)
      [File.basename(path), library.diagnose(path)]
    end
  end

  it 'reports no diagnostics on features' do
    expect(diagnose_features.values).to all(be_empty)
  end

  it 'reports only RuboCop offenses on features without the Exclude' do
    File.delete(File.join(@root, '.rubocop.yml'))
    sources = diagnose_features.values.flatten.map { |diag| diag[:source] }.uniq
    expect(sources).to eq(['rubocop'])
  end

  it 'does not format features' do
    host = Solargraph::LanguageServer::Host.new
    host.prepare ''
    results = features.to_h do |path|
      uri = Solargraph::LanguageServer::UriHelpers.file_to_uri(path)
      host.open uri, File.read(path), 1
      message = Solargraph::LanguageServer::Message::TextDocument::Formatting.new(
        host, { 'params' => { 'textDocument' => { 'uri' => uri } } }
      )
      message.process
      [File.basename(path), message.result]
    end
    expect(results.values).to all(eq([]))
  end
end
