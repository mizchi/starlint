# starlint

simple linter for MoonBit language.

## test

```
moon test --target wasm-gc
```

## basic usage

Install:

```
moon install mizchi/starlint/cmd/starlint
```

```
starlint # show help
starlint . # auto scan current project
starlint foo.mbt # check this file
starlint --rule prefer_pipeline # show only this rule's diagnostics
starlint --fix # apply all autofixes
starlint --fix --rule if_let_to_match # apply fixes for one rule only
starlint --by-rule foo.mbt # group diagnostics by rule
starlint doc # show rule list and defaults
starlint init # generate starlint.json (with rule_groups guidance)
starlint --ai # output AI review metadata (module/file/function/test names + doc tests)
starlint analyze # baseline compare (default: .starlint/latest.json, fallback: .starlint/<git-hash>.json) + AI metadata dump
starlint analyze --compare path/to/baseline.json
```

## embed as library

`mizchi/starlint/tasks/lint` is the reference implementation used by this
repository.

When embedding in your own app/library, define your own wrapper module (for
example `myapp/tasks/lint`) and compose rules there for each runtime
environment.

```mbt nocheck
// moon.pkg
import {
  "mizchi/starlint",
  "mizchi/starlint/tasks/lint",
}

///|
fn run_lint(source : String) -> Array[@starlint.Diagnostic] raise {
  let config = @starlint.LintConfig::recommended()
  let (diags, reports) = @lint.lint_source(source, config~)
  if reports.length() > 0 {
    return []
  }
  diags
}
```

`mizchi/starlint/internal` is an implementation detail package and may change
without compatibility guarantees.

### custom lint plugin (eslint-like ctx)

You can inject user-defined rules with `Rule::from_plugin(...)`.
The plugin receives `ctx` (report + AST utilities), similar to ESLint's
`create(context)` style.

```mbt nocheck
// moon.pkg
import {
  "mizchi/starlint",
  "mizchi/starlint/tasks/lint",
}

///|
fn plugin_rule() -> @starlint.Rule {
  @starlint.Rule::from_plugin(
    id="my_plugin_rule",
    description="example plugin rule",
    tags=["my-plugin"],
    enabled_by_default=false,
    plugin=ctx => {
      ctx.visit_exprs(expr => {
        match ctx.match_call_info(expr) {
          Some((name, args, loc)) if name == "assert_true" =>
            match ctx.first_positional_arg(args) {
              Some(arg) if ctx.match_constant_bool(arg) == Some(true) =>
                ctx.report(
                  loc~,
                  message="avoid assert_true(true)",
                  suggestion="assert_true(actual)",
                )
              _ => ()
            }
          _ => ()
        }
      })
    },
  )
}

///|
fn run_with_plugin(source : String) -> Array[@starlint.Diagnostic] {
  let config = @starlint.LintConfig::enable_categories(["my-plugin"])
  let (diags, _reports) = @lint.lint_source_with_extra_rules(
    source,
    [plugin_rule()],
    config~,
  )
  diags
}
```

### environment-specific extension samples

1. CLI (`myapp lint foo.mbt`)

```mbt nocheck
///|
pub fn lint_for_cli(source : String, filename : String) -> Int {
  let config = @starlint.LintConfig::recommended()
  let (diags, reports) = @lint.lint_source_with_extra_rules(
    source,
    [plugin_rule()],
    filename~,
    config~,
  )
  if reports.length() > 0 {
    return 2
  }
  if diags.length() > 0 {
    return 1
  }
  0
}
```

2. Editor on-save (fast subset)

```mbt nocheck
///|
pub fn lint_on_save(
  source : String,
  filename : String,
) -> Array[@starlint.Diagnostic] {
  let config = @starlint.LintConfig::enable_categories(["fp", "my-plugin"])
  let (diags, reports) = @lint.lint_source_with_extra_rules(
    source,
    [plugin_rule()],
    filename~,
    config~,
  )
  if reports.length() > 0 {
    []
  } else {
    diags
  }
}
```

3. CI / batch runner (single composed ruleset)

```mbt nocheck
///|
pub fn rules_for_ci() -> Array[@starlint.Rule] {
  @lint.compose_rules([plugin_rule()])
}
```

## ai metadata (--ai)

`--ai` emits a structured text dump for review by LLMs. It does not run lint rules.

It includes:

- module name and package names
- public/private function names
- test names + warnings for unnamed or check-style names
- doc tests from `///` doc comments and `*.mbt.md` files

Use it when you want an AI to infer module intent and review naming or test coverage.

starlint walks up from the current directory to find `moon.mod.json`, and uses that
module root as the base for config and file discovery.

You can also start from a specific directory:

```
starlint --config path/to/starlint.json src/foo.mbt
```

## embed as CLI main

Use starlint as a library-driven CLI by calling `@cli.run(...)` from your own
`main` (e.g. `src/cmd/starlint/main.mbt`).

```
// moon.pkg
import {
  "mizchi/starlint/cmd/starlint" @cli,
  "moonbitlang/x/sys",
}
```

```mbt nocheck
///|
fn main {
  let argv = @sys.get_cli_args()[1:].to_array()
  @cli.run(argv) // uses PWD (or INIT_CWD) to locate moon.mod.json
  // or: @cli.run(argv, start_dir="path/to/project")
}
```

## install

From mooncakes:

```
moon install mizchi/starlint/cmd/starlint
```

Pin a specific version:

```
moon install mizchi/starlint/cmd/starlint@v0.8.0
```

Install to a custom bin directory:

```
moon install --bin ~/.local/bin mizchi/starlint/cmd/starlint
```

For local development builds:

```
moon install ./cmd/starlint
```

## configuration

starlint supports a JSON config file at `starlint.json` or `.starlint.json`.

### preset (recommended)

```
{
  "preset": "recommended"
}
```

The `recommended` preset enables: `fp`, `size`, `async`, `error` by default (perf is off).

### module/test categories (optional)

These are optional add-ons. `module` includes doc comment requirements for `pub fn` / `pub enum`,
which can be noisy, so it is **off by default**. Enable when you want stricter module conventions.

```
{
  "preset": "recommended",
  "categories": {
    "module": { "enabled": true },
    "test": { "enabled": true }
  }
}
```

- `module` rules enforce doc comments on `pub fn` / `pub enum`, and restrict `using` to `file.mbt`.
- `test` rules detect trivial asserts and prefer input/expected/actual style.

### ignore / overrides

```
{
  "ignore": ["target/*", "_build/*", "*.gen.mbt"],
  "overrides": [
    {
      "files": ["tests/*", "*_test.mbt"],
      "rules": { "prefer_arrow_fn": "off" },
      "categories": { "perf": { "enabled": false } }
    }
  ]
}
```

- `ignore` skips matching files.
- `overrides` applies per-file rule/category settings. Patterns use `*`; if a pattern contains `/`, it matches the full path, otherwise the basename.
