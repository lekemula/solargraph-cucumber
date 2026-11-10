# frozen_string_literal: true

require_relative 'lib/solargraph/cucumber/version'

Gem::Specification.new do |spec|
  spec.name = 'solargraph-cucumber'
  spec.version = Solargraph::Cucumber::VERSION
  spec.authors = ['Lekë Mula']
  spec.email = ['leke.mula@gmail.com']

  spec.summary = 'Solargraph plugin supporting Cucumber step navigation'
  spec.description = 'This plugin links Cucumber steps in feature files to their Ruby step definitions in Solargraph.'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.0'

  spec.metadata['source_code_uri'] = 'https://github.com/lekemula/solargraph-cucumber'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ doc/ .git .circleci appveyor Gemfile])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'cucumber-cucumber-expressions', '> 17', '< 21'
  spec.add_dependency 'cucumber-gherkin', '> 36', '< 43'
  spec.add_dependency 'rubocop-ast', '>= 1.0'
  spec.add_dependency 'solargraph', '>= 0.56.0'

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
  spec.metadata['rubygems_mfa_required'] = 'true'
end
