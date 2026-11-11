# Solargraph::Cucumber - A [Solargraph](https://solargraph.org/) plugin for [Cucumber](https://cucumber.io/) support

> [!WARNING]
> Work in progress. The plugin depends on Solargraph changes that are not released yet:
> [castwide/solargraph#1489](https://github.com/castwide/solargraph/pull/1489). Until it is merged, use Solargraph from
> that branch, as shown below.

This gem adds Cucumber support to Solargraph:
  - go to definition from a step in a `.feature` file to its Ruby step definition
  - hover docs for step keywords (`Given`, `When`, `Then`, `And`, `But`, `*`) in `.feature` files
  - hover docs for the Cucumber DSL (step keywords, `Before`/`After`/`Around`/`AfterStep`, `World`, `ParameterType`) in
    Ruby files under `features/`
  - and more to come... ⏲️

## Demo

https://github.com/user-attachments/assets/ca371bf8-d694-4d82-8823-39cf3d79b44f


## Installation

Add it to your Gemfile. Until castwide/solargraph#1489 is released, take Solargraph from its branch:

```ruby
group :development do
  gem 'solargraph', github: 'lekemula/solargraph', branch: 'cucumber', require: false
  gem 'solargraph-cucumber', github: 'lekemula/solargraph-cucumber', require: false
end
```

Your editor's Solargraph client must also send `.feature` buffers to the server. In Neovim:

```lua
vim.lsp.config('solargraph', { filetypes = { 'ruby', 'cucumber' } })
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

Hover docs for the Cucumber DSL come from the `cucumber` gem, so it must be in your bundle with its docs cached:

```sh
bundle exec solargraph gems cucumber
```

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

The `Gemfile` takes `solargraph` from the `cucumber` branch of
[lekemula/solargraph](https://github.com/lekemula/solargraph/tree/cucumber) (castwide/solargraph#1489). Set
`SOLARGRAPH_PATH` to use a local checkout of it instead.

The end-to-end specs run against the sandbox project in `~/Projects/open_source/cucumber-sandbox` and are skipped
without it; set `CUCUMBER_SANDBOX` to point them elsewhere.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/lekemula/solargraph-cucumber.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
