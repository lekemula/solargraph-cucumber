# Solargraph::Cucumber - A [Solargraph](https://solargraph.org/) plugin for [Cucumber](https://cucumber.io/) support

> [!WARNING]
> Work in progress. The plugin registers itself with Solargraph but does not provide any features yet.

This gem aims to add Cucumber support to Solargraph:
  - go to definition from a step in a `.feature` file to its Ruby step definition
  - and more to come... ⏲️

## Installation

Add it to your Gemfile:

```ruby
group :development do
  gem 'solargraph', require: false
  gem 'solargraph-cucumber', require: false
end
```

Add `solargraph-cucumber` to your `.solargraph.yml` as a plugin, and include your feature files in the workspace. An
`include` replaces Solargraph's default, so keep `**/*.rb` in it:

```yaml
include:
  - "**/*.rb"
  - "features/**/*.feature"
plugins:
  - solargraph-cucumber
```

Feature files outside the workspace `include` are not supported: with more than one of them open, Solargraph can
lose track of the one you navigate from and return no definition.

### Keep RuboCop off `.feature` files

Solargraph reads a `.feature` file as generated Ruby code. It does not typecheck or format that code, but its `rubocop`
reporter lints it unless your `.rubocop.yml` excludes feature files:

```yaml
AllCops:
  Exclude:
    - '**/*.feature'
```

RuboCop reads this from the `.rubocop.yml` of the directory Solargraph runs in, usually the project root.

## Development

After checking out the repo, run `bundle install`, then `bundle exec rake` to run the specs and RuboCop.

The `Gemfile` points `solargraph` at a local checkout in `~/Projects/open_source/solargraph`.
Set `SOLARGRAPH_PATH` to use another one.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/lekemula/solargraph-cucumber.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
