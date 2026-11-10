# Glossary

**Step**
A line in a Gherkin scenario that starts with a keyword (`Given`, `When`, `Then`, `And`, `But`, `*` or a localized
equivalent), followed by the step text. Steps live in `.feature` files.

**Step Definition**
Ruby code that runs when a Step matches: a call such as `Given(expression) { ... }`, usually under
`features/step_definitions/`. The keyword used to define it does not limit which Steps it matches.

**Step Expression**
The pattern a Step Definition matches Step text against. It is either a Cucumber Expression (a string with
placeholders such as `{int}` or `{string}`) or a regular expression.

**Parameter Type**
A named placeholder usable in a Cucumber Expression, such as `{int}`. Cucumber ships built-in Parameter Types, and
projects define their own with `ParameterType(name:, regexp:, ...)`.

**Approximate Match**
A match between a Step and a Step Definition whose Step Expression or Parameter Type could only be read in part,
for example because it is built at runtime. It may be wrong, so exact matches rank ahead of it.

**Shadow Source**
A Ruby source the plugin builds to stand in for a non-Ruby document, such as a `.feature` file, so that Solargraph's
Ruby-only machinery can work with it. It keeps the document's lines and columns: each Step's text sits at the same line
and column in the Shadow Source as in the document, so a position in one is the same position in the other.
