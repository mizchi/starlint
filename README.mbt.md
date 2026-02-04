# moonlint

simple linter for MoonBit language.

## test

```
moon test --target wasm-gc
```

## basic usage

```
moonlint.exe # auto scan current project
moonlint.exe foo.mbt # check this file
moonlint.exe --by-rule foo.mbt # group diagnostics by rule
moonlint.exe doc # show rule list and defaults
moonlint.exe init # generate moonlint.json (with rule_groups guidance)
```

moonlint walks up from the current directory to find `moon.mod.json`, and uses that
module root as the base for config and file discovery.

## embed as CLI main

Use moonlint as a library-driven CLI by calling `@cli.run(...)` from your own
`main` (e.g. `src/internal/cli.mbt`).

```
// moon.pkg
import {
  "myfreess/moonlint/cli",
  "moonbitlang/x/sys",
}
```

```mbt
///|
fn main {
  let argv = @sys.get_cli_args()[1:].to_array()
  @cli.run(argv)
}
```

## install

```
just install
```
## configuration

moonlint supports a JSON config file at `moonlint.json` or `.moonlint.json`.

### preset (recommended)

```
{
  "preset": "recommended"
}
```

The `recommended` preset enables: `fp`, `size`, `async`, `error` by default (perf is off).

### module/test categories

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
